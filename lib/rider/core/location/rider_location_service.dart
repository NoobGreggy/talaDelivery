part of '../../app.dart';

class RiderLatLng {
  const RiderLatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

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
    this.accuracy = LocationAccuracy.medium,
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
      return RiderLatLng(position.latitude, position.longitude);
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
    this.interval = const Duration(seconds: 20),
  });

  final RiderLocationSource source;
  final Future<void> Function(RiderLatLng position) postLocation;
  final Duration interval;

  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

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
    try {
      await postLocation(position);
      return RiderLocationReport.posted;
    } catch (_) {
      return RiderLocationReport.failed;
    }
  }

  /// Starts immediate + periodic reporting. Safe to call repeatedly.
  void start() {
    if (_running) return;
    _running = true;
    reportOnce();
    _timer = Timer.periodic(interval, (_) => reportOnce());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }
}
