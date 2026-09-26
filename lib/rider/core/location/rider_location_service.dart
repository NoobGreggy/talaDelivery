part of '../../app.dart';

class RiderLatLng {
  const RiderLatLng(
    this.latitude,
    this.longitude, {
    this.accuracy,
    this.heading,
    this.speed,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final DateTime? recordedAt;

  @override
  String toString() => 'RiderLatLng($latitude, $longitude)';
}

enum RiderLocationPermission {
  granted,
  denied,
  deniedForever,
  unknown;

  bool get isGranted => this == RiderLocationPermission.granted;
}

/// Outcome of a single location report, so the UI can surface only the
/// important failures (permissions) without noise on every tick.
enum RiderLocationReport {
  posted,
  unchanged,
  lowAccuracy,
  permissionDenied,
  permissionPermanentlyDenied,
  locationUnavailable,
  failed,
}

/// Location source that can be swapped for a fake in tests.
abstract class RiderLocationSource {
  Future<RiderLocationPermission> permissionStatus();
  Future<RiderLocationPermission> requestPermission();
  Future<RiderLatLng?> currentPosition();
  Future<bool> isLocationServiceEnabled();
}

class GeolocatorRiderLocationSource implements RiderLocationSource {
  GeolocatorRiderLocationSource({
    this.accuracy = LocationAccuracy.high,
    this.maxAge = const Duration(seconds: 45),
  });

  final LocationAccuracy accuracy;
  final Duration maxAge;

  static RiderLocationPermission _mapPermission(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.whileInUse ||
      LocationPermission.always => RiderLocationPermission.granted,
      LocationPermission.denied => RiderLocationPermission.denied,
      LocationPermission.deniedForever => RiderLocationPermission.deniedForever,
      LocationPermission.unableToDetermine => RiderLocationPermission.unknown,
    };
  }

  @override
  Future<RiderLocationPermission> permissionStatus() async {
    try {
      return _mapPermission(await Geolocator.checkPermission());
    } catch (_) {
      return RiderLocationPermission.unknown;
    }
  }

  @override
  Future<RiderLocationPermission> requestPermission() async {
    try {
      return _mapPermission(await Geolocator.requestPermission());
    } catch (_) {
      return RiderLocationPermission.unknown;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RiderLatLng?> currentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      );
      final timestamp = position.timestamp;
      if (DateTime.now().difference(timestamp).abs() > maxAge) {
        return null;
      }
      return RiderLatLng(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy >= 0 ? position.accuracy : null,
        heading: position.heading >= 0 && position.heading <= 360
            ? position.heading
            : null,
        speed: position.speed >= 0 ? position.speed : null,
        recordedAt: position.timestamp,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Periodically reports the rider's position to the backend while online.
class RiderLocationService {
  RiderLocationService({
    required this.source,
    required this.postLocation,
    this.postTrackedLocation,
    this.interval = const Duration(seconds: 20),
    this.activeInterval = const Duration(seconds: 5),
    this.minimumDistanceMeters = 10,
    this.maximumSilence = const Duration(seconds: 30),
    this.maximumAccuracyMeters = 100,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RiderLocationSource source;
  final Future<void> Function(RiderLatLng position) postLocation;
  final Future<void> Function(RiderLatLng position, int deliveryId)?
  postTrackedLocation;
  final Duration interval;
  final Duration activeInterval;
  final double minimumDistanceMeters;
  final Duration maximumSilence;
  final double maximumAccuracyMeters;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _running = false;
  int? _activeDeliveryId;
  RiderLatLng? _lastPostedPosition;
  DateTime? _lastPostedAt;

  bool get isRunning => _running;
  int? get activeDeliveryId => _activeDeliveryId;

  void setActiveDelivery(int? deliveryId) {
    if (_activeDeliveryId == deliveryId) return;
    _activeDeliveryId = deliveryId;
    _lastPostedPosition = null;
    _lastPostedAt = null;
    if (_running) _schedule();
  }

  /// Reports once and returns the outcome so the caller can surface
  /// permission problems.
  Future<RiderLocationReport> reportOnce() async {
    if (!await source.isLocationServiceEnabled()) {
      return RiderLocationReport.locationUnavailable;
    }
    final permission = await source.permissionStatus();
    if (!permission.isGranted) {
      final requested = await source.requestPermission();
      if (!requested.isGranted) {
        return requested == RiderLocationPermission.deniedForever
            ? RiderLocationReport.permissionPermanentlyDenied
            : RiderLocationReport.permissionDenied;
      }
    }
    final position = await source.currentPosition();
    if (position == null) return RiderLocationReport.locationUnavailable;
    if (position.accuracy != null &&
        position.accuracy! > maximumAccuracyMeters) {
      return RiderLocationReport.lowAccuracy;
    }
    final previous = _lastPostedPosition;
    final lastPostedAt = _lastPostedAt;
    if (previous != null &&
        lastPostedAt != null &&
        _clock().difference(lastPostedAt) < maximumSilence &&
        _distanceMeters(previous, position) < minimumDistanceMeters) {
      return RiderLocationReport.unchanged;
    }
    try {
      final deliveryId = _activeDeliveryId;
      final trackedPost = postTrackedLocation;
      if (deliveryId != null && trackedPost != null) {
        await trackedPost(position, deliveryId);
      } else {
        await postLocation(position);
      }
      _lastPostedPosition = position;
      _lastPostedAt = _clock();
      return RiderLocationReport.posted;
    } catch (_) {
      return RiderLocationReport.failed;
    }
  }

  static double _distanceMeters(RiderLatLng from, RiderLatLng to) {
    const earthRadiusMeters = 6371000.0;
    final fromLatitude = from.latitude * math.pi / 180;
    final toLatitude = to.latitude * math.pi / 180;
    final latitudeDelta = (to.latitude - from.latitude) * math.pi / 180;
    final longitudeDelta = (to.longitude - from.longitude) * math.pi / 180;
    final haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(fromLatitude) *
            math.cos(toLatitude) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  /// Starts immediate + periodic reporting. Safe to call repeatedly.
  void start({bool reportImmediately = true}) {
    if (_running) return;
    _running = true;
    _schedule(reportImmediately: reportImmediately);
  }

  void _schedule({bool reportImmediately = true}) {
    _timer?.cancel();
    if (reportImmediately) unawaited(reportOnce());
    final frequency = _activeDeliveryId == null ? interval : activeInterval;
    _timer = Timer.periodic(frequency, (_) => unawaited(reportOnce()));
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }
}
