part of '../../../app.dart';

class CustomerDeliveryMap extends StatefulWidget {
  const CustomerDeliveryMap({
    super.key,
    required this.delivery,
    this.liveRiderLocation,
    this.animateMovement = true,
  });

  final CustomerDelivery delivery;
  final CustomerRiderLocation? liveRiderLocation;

  /// Smoothly eases the rider marker between pushed samples. Set to `false`
  /// to snap directly to each sample instead (used when reduced motion is on
  /// or where the map must mirror the server exactly).
  final bool animateMovement;

  @override
  State<CustomerDeliveryMap> createState() => _CustomerDeliveryMapState();
}

class _CustomerDeliveryMapState extends State<CustomerDeliveryMap>
    with SingleTickerProviderStateMixin {
  static const _riderMoveDuration = Duration(seconds: 4);

  /// Snap to the sample instead of animating past this distance.
  static const _moveSnapDistanceMeters = 400.0;

  /// Snap to the sample when it predates this window.
  static const _staleLocationWindow = Duration(seconds: 30);

  mapbox.MapboxMap? controller;
  mapbox.CircleAnnotationManager? circleManager;
  mapbox.CircleAnnotation? pickupCircle;
  mapbox.CircleAnnotation? destinationCircle;
  mapbox.CircleAnnotation? riderCircle;
  bool styleLoaded = false;

  late final AnimationController _riderSlide;
  CustomerMapPoint? _riderShown;
  CustomerMapPoint? _currentFrom;
  CustomerMapPoint? _currentTo;
  int? _trackedDeliveryId;
  bool _reduceMotion = false;

  CustomerRiderLocation? get riderLocation =>
      widget.liveRiderLocation ?? widget.delivery.riderLocation;

  @override
  void initState() {
    super.initState();
    _trackedDeliveryId = widget.delivery.id;
    _riderSlide = AnimationController(
      vsync: this,
      duration: _riderMoveDuration,
    )
      ..addListener(_onRiderTick)
      ..addStatusListener(_onRiderStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(CustomerDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delivery.id != widget.delivery.id) {
      // Never interpolate across deliveries; drop the old marker state.
      _trackedDeliveryId = widget.delivery.id;
      _riderSlide.stop();
      _currentFrom = null;
      _currentTo = null;
      _riderShown = null;
      _riderSlide.value = 1;
    }
    if (styleLoaded) unawaited(_syncAnnotations());
  }

  @override
  void dispose() {
    _riderSlide.dispose();
    super.dispose();
  }

  void _onRiderTick() {
    final from = _currentFrom;
    final to = _currentTo;
    if (to == null) return;
    _riderShown = _interpolate(from ?? to, to, _riderSlide.value);
    unawaited(_updateRiderCircle(_riderShown!));
  }

  void _onRiderStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _riderShown = _currentTo;
      _currentFrom = null;
      _currentTo = null;
    }
  }

  Future<void> _syncAnnotations() async {
    final map = controller;
    if (map == null || !styleLoaded) return;
    pickupCircle = await _upsertCircle(
      map,
      pickupCircle,
      widget.delivery.pickupPoint,
      0xFF2563EB,
      8,
    );
    destinationCircle = await _upsertCircle(
      map,
      destinationCircle,
      widget.delivery.deliveryPoint,
      0xFF16A34A,
      9,
    );
    final rider = riderLocation;
    if (rider != null && rider.hasCoordinates) {
      await _moveRider(rider);
    }
  }

  Future<void> _moveRider(CustomerRiderLocation next) async {
    final target = CustomerMapPoint(next.latitude!, next.longitude!);
    final from = _riderShown;
    if (from != null && _samePoint(from, target)) return;

    final changedDelivery =
        _trackedDeliveryId != null && next.deliveryId != _trackedDeliveryId;
    if (changedDelivery) _trackedDeliveryId = next.deliveryId;

    final snap =
        !widget.animateMovement ||
        _reduceMotion ||
        from == null ||
        changedDelivery ||
        _shouldSnap(next, from);
    if (snap) {
      _riderSlide.stop();
      _currentFrom = null;
      _currentTo = null;
      _riderShown = target;
      _riderSlide.value = 1;
      await _updateRiderCircle(target);
      return;
    }

    _currentFrom = from;
    _currentTo = target;
    _riderSlide.forward(from: 0);
  }

  bool _shouldSnap(CustomerRiderLocation next, CustomerMapPoint from) {
    final target = CustomerMapPoint(next.latitude!, next.longitude!);
    if (_distanceMeters(from, target) > _moveSnapDistanceMeters) return true;
    final recordedAt = next.recordedAt;
    if (recordedAt != null &&
        DateTime.now().difference(recordedAt) > _staleLocationWindow) {
      return true;
    }
    return false;
  }

  Future<void> _updateRiderCircle(CustomerMapPoint point) async {
    final map = controller;
    if (map == null || !styleLoaded || circleManager == null) return;
    final options = mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(point.longitude, point.latitude),
      ),
      circleColor: 0xFFF97316,
      circleRadius: 10,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3,
    );
    final manager = circleManager!;
    if (riderCircle == null) {
      riderCircle = await manager.create(options);
      return;
    }
    riderCircle
      ?.geometry = options.geometry;
    await manager.update(riderCircle!);
  }

  Future<mapbox.CircleAnnotation?> _upsertCircle(
    mapbox.MapboxMap map,
    mapbox.CircleAnnotation? circle,
    CustomerMapPoint? point,
    int color,
    double radius,
  ) async {
    if (point == null) return circle;
    final options = mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(point.longitude, point.latitude),
      ),
      circleColor: color,
      circleRadius: radius,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3,
    );
    final manager = circleManager;
    if (manager == null) return circle;
    if (circle == null) return manager.create(options);
    circle
      ..geometry = options.geometry
      ..circleColor = options.circleColor
      ..circleRadius = options.circleRadius
      ..circleStrokeColor = options.circleStrokeColor
      ..circleStrokeWidth = options.circleStrokeWidth;
    await manager.update(circle);
    return circle;
  }

  CustomerMapPoint _interpolate(
    CustomerMapPoint from,
    CustomerMapPoint to,
    double t,
  ) {
    final eased = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    return CustomerMapPoint(
      from.latitude + (to.latitude - from.latitude) * eased,
      from.longitude + (to.longitude - from.longitude) * eased,
    );
  }

  bool _samePoint(CustomerMapPoint a, CustomerMapPoint b) =>
      a.latitude == b.latitude && a.longitude == b.longitude;

  double _distanceMeters(CustomerMapPoint a, CustomerMapPoint b) {
    const earthRadius = 6371000.0;
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final h = _sin2(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * _sin2(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  double _sin2(double value) => math.sin(value) * math.sin(value);

  @override
  Widget build(BuildContext context) {
    final points = [
      widget.delivery.pickupPoint,
      widget.delivery.deliveryPoint,
      if (riderLocation case final rider?)
        if (rider.hasCoordinates)
          CustomerMapPoint(rider.latitude!, rider.longitude!),
    ].whereType<CustomerMapPoint>().toList(growable: false);
    if (points.isEmpty) {
      return const InfoBanner(
        icon: Icons.location_off_outlined,
        text: 'Map coordinates are not available for this delivery.',
      );
    }
    final center = CustomerMapPoint(
      points.map((point) => point.latitude).reduce((a, b) => a + b) /
          points.length,
      points.map((point) => point.longitude).reduce((a, b) => a + b) /
          points.length,
    );
    final mapConfig = CustomerMapConfig.fromEnvironment();
    if (!mapConfig.isConfigured) {
      return const InfoBanner(
        icon: Icons.map_outlined,
        text: 'Mapbox is not configured. Add TALA_MAPBOX_ACCESS_TOKEN to your config file.',
      );
    }
    final palette = appPaletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 270,
        child: Stack(
          children: [
            mapbox.MapWidget(
              styleUri: mapConfig.styleUrl,
              viewport: mapbox.CameraViewportState(
                center: mapbox.Point(
                  coordinates: mapbox.Position(
                    center.longitude,
                    center.latitude,
                  ),
                ),
                zoom: 13,
              ),
              onMapCreated: (value) async {
                controller = value;
                circleManager = await value.annotations
                    .createCircleAnnotationManager();
                if (styleLoaded) unawaited(_syncAnnotations());
              },
              onStyleLoadedListener: (_) {
                styleLoaded = true;
                unawaited(_syncAnnotations());
              },
            ),
            Positioned(
              left: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Text(
                    'Blue: store  •  Green: you  •  Orange: rider',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}