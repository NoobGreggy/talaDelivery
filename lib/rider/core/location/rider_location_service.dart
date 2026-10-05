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

abstract class RiderStreamingLocationSource implements RiderLocationSource {
  Stream<RiderLatLng> positions({required bool background});
}

class GeolocatorRiderLocationSource implements RiderStreamingLocationSource {
  GeolocatorRiderLocationSource({
    this.accuracy = LocationAccuracy.high,
    this.maxAge = const Duration(seconds: 45),
  });

  final LocationAccuracy accuracy;
  final Duration maxAge;
  RiderLatLng? _latest;

  static RiderLatLng _point(Position position) => RiderLatLng(
    position.latitude,
    position.longitude,
    accuracy: position.accuracy >= 0 ? position.accuracy : null,
    heading: position.heading >= 0 && position.heading <= 360
        ? position.heading
        : null,
    speed: position.speed >= 0 ? position.speed : null,
    recordedAt: position.timestamp,
  );

  @override
  Stream<RiderLatLng> positions({required bool background}) {
    _latest = null;
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Tala delivery location sharing',
                notificationText: 'Sharing your location for your active delivery. Return to Tala to complete it.',
                notificationChannelName: 'Active delivery tracking',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: accuracy,
        distanceFilter: 5,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    } else {
      settings = LocationSettings(accuracy: accuracy, distanceFilter: 5);
    }
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((position) {
          final point = _point(position);
          _latest = point;
          return point;
        });
  }

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
      final cached = _latest;
      if (cached?.recordedAt != null &&
          DateTime.now().difference(cached!.recordedAt!).abs() <= maxAge) {
        return cached;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: const Duration(seconds: 12),
        ),
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
  StreamSubscription<RiderLatLng>? _stream;
  Future<void> _streamCancellation = Future<void>.value();
  int? _streamStarting;
  bool? _streamBackground;
  bool _foreground = true;
  bool _disposed = false;
  int _generation = 0;
  bool _running = false;
  bool _reportInFlight = false;
  int? _activeDeliveryId;
  RiderLatLng? _lastPostedPosition;
  DateTime? _lastPostedAt;
  final ValueNotifier<RiderLatLng?> _position = ValueNotifier(null);

  bool get isRunning => _running;
  int? get activeDeliveryId => _activeDeliveryId;
  ValueListenable<RiderLatLng?> get position => _position;

  void setForeground(bool value) => _foreground = value;

  void setActiveDelivery(int? deliveryId) {
    if (_activeDeliveryId == deliveryId) return;
    _activeDeliveryId = deliveryId;
    _lastPostedPosition = null;
    _lastPostedAt = null;
    _generation++;
    _cancelStream();
    if (_running) {
      _schedule();
      unawaited(_ensureStream());
    }
  }

  /// Reports once and returns the outcome so the caller can surface
  /// permission problems. Skips the tick while a previous report is still in
  /// flight so slow GPS/network calls can never overlap.
  Future<RiderLocationReport> reportOnce() async {
    if (_reportInFlight) return RiderLocationReport.unchanged;
    _reportInFlight = true;
    final startedAt = DateTime.now();
    try {
      return await _reportOnceInner();
    } finally {
      _reportInFlight = false;
      _riderPerfTrace('rider.location.report', startedAt);
    }
  }

  Future<RiderLocationReport> _reportOnceInner() async {
    final generation = _generation;
    if (!await source.isLocationServiceEnabled()) {
      return RiderLocationReport.locationUnavailable;
    }
    final permission = await source.permissionStatus();
    if (!permission.isGranted) {
      if (!_foreground) return RiderLocationReport.permissionDenied;
      final requested = await source.requestPermission();
      if (!requested.isGranted) {
        return requested == RiderLocationPermission.deniedForever
            ? RiderLocationReport.permissionPermanentlyDenied
            : RiderLocationReport.permissionDenied;
      }
    }
    if (_disposed || generation != _generation) {
      return RiderLocationReport.unchanged;
    }
    await _ensureStream();
    final position = await source.currentPosition();
    if (_disposed || generation != _generation) {
      return RiderLocationReport.unchanged;
    }
    if (position == null) return RiderLocationReport.locationUnavailable;
    if (!RiderNavigation.valid(position)) {
      return RiderLocationReport.locationUnavailable;
    }
    if (position.recordedAt != null &&
        _clock().difference(position.recordedAt!).abs() >
            const Duration(seconds: 45)) {
      return RiderLocationReport.locationUnavailable;
    }
    if (position.accuracy != null &&
        position.accuracy! > maximumAccuracyMeters) {
      return RiderLocationReport.lowAccuracy;
    }
    _position.value = position;
    final previous = _lastPostedPosition;
    final lastPostedAt = _lastPostedAt;
    if (previous != null &&
        lastPostedAt != null &&
        _clock().difference(lastPostedAt) < maximumSilence &&
        _distanceMeters(previous, position) < minimumDistanceMeters) {
      return RiderLocationReport.unchanged;
    }
    final deliveryId = _activeDeliveryId;
    final trackedPost = postTrackedLocation;
    try {
      if (deliveryId != null && trackedPost != null) {
        await trackedPost(position, deliveryId);
      } else {
        await postLocation(position);
      }
    } catch (_) {
      return RiderLocationReport.failed;
    }
    if (!_disposed && generation == _generation) {
      _lastPostedPosition = position;
      _lastPostedAt = _clock();
    }
    return RiderLocationReport.posted;
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

  Future<void> _ensureStream() async {
    final streaming = source;
    if (!_running || streaming is! RiderStreamingLocationSource) return;
    final background = _activeDeliveryId != null;
    if (_stream != null && _streamBackground == background) return;
    if (_streamStarting == _generation) return;
    // Foreground services must be started while the app is visible.
    if (!_foreground) return;
    _cancelStream();
    final generation = _generation;
    _streamStarting = generation;
    await _streamCancellation;
    if (!_running || _disposed || generation != _generation || !_foreground) {
      if (_streamStarting == generation) _streamStarting = null;
      return;
    }
    _streamBackground = background;
    _streamStarting = null;
    _stream = streaming
        .positions(background: background)
        .listen(
          (point) {
            if (!_running ||
                _disposed ||
                generation != _generation ||
                !RiderNavigation.valid(point)) {
              return;
            }
            if ((point.accuracy == null ||
                    point.accuracy! <= maximumAccuracyMeters) &&
                (point.recordedAt == null ||
                    _clock().difference(point.recordedAt!).abs() <=
                        const Duration(seconds: 45))) {
              // Own map remains responsive even while an HTTP report is pending.
              _position.value = point;
            }
            unawaited(reportOnce());
          },
          onError: (Object error) {
            // Periodic reconciliation retries GPS without crashing the delivery UI.
            if (generation == _generation) _cancelStream();
          },
          onDone: () {
            if (generation == _generation) _cancelStream();
          },
        );
  }

  void _cancelStream() {
    final stream = _stream;
    _stream = null;
    _streamBackground = null;
    if (stream != null) {
      _streamCancellation = _streamCancellation
          .then((_) => stream.cancel())
          .catchError((Object _) {});
    }
  }

  void stop() {
    _generation++;
    _running = false;
    _cancelStream();
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    stop();
    _position.dispose();
  }

  /// Reschedules reporting after the OS suspended the process during app
  /// pause. Bypasses the `start` guard exactly once so timers are restored
  /// even when the old run was never explicitly stopped.
  void restart() {
    stop();
    start(reportImmediately: false);
  }
}
