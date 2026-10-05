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
  mapbox.CircleAnnotation? riderCircle;
  mapbox.CircleAnnotation? storeCircle;
  mapbox.CircleAnnotation? customerCircle;
  bool _syncing = false;
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
    _riderSlide = AnimationController(vsync: this, duration: _riderMoveDuration)
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
    unawaited(_updateRiderCircle(_riderShown!).catchError((Object _) {}));
  }

  void _onRiderStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _riderShown = _currentTo;
      _currentFrom = null;
      _currentTo = null;
    }
  }

  Future<void> _syncAnnotations() async {
    if (!mounted || controller == null || !styleLoaded || _syncing) return;
    _syncing = true;
    try {
      storeCircle = await _stopPin(
        widget.delivery.pickupPoint,
        storeCircle,
        0xFF2563EB,
      );
      customerCircle = await _stopPin(
        widget.delivery.deliveryPoint,
        customerCircle,
        0xFF16A34A,
      );
      final rider = riderLocation;
      if (rider != null && rider.hasCoordinates) {
        await _moveRider(rider);
      }
    } catch (_) {
      // Map teardown must not interrupt incoming order updates.
    } finally {
      _syncing = false;
    }
  }

  Future<mapbox.CircleAnnotation?> _stopPin(
    CustomerMapPoint? point,
    mapbox.CircleAnnotation? marker,
    int color,
  ) async {
    final manager = circleManager;
    if (manager == null ||
        point == null ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return marker;
    }
    final options = mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(point.longitude, point.latitude),
      ),
      circleColor: color,
      circleRadius: 9,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3,
    );
    if (marker == null) return manager.create(options);
    marker.geometry = options.geometry;
    await manager.update(marker);
    return marker;
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
      await _focusRider(target, animate: false);
      return;
    }

    _currentFrom = from;
    _currentTo = target;
    _riderSlide.forward(from: 0);
    await _focusRider(target, animate: true);
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
    if (!mounted || map == null || !styleLoaded || circleManager == null) {
      return;
    }
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
    riderCircle?.geometry = options.geometry;
    await manager.update(riderCircle!);
  }

  Future<void> _focusRider(
    CustomerMapPoint point, {
    required bool animate,
  }) async {
    final map = controller;
    if (map == null) return;
    final points =
        [point, widget.delivery.pickupPoint, widget.delivery.deliveryPoint]
            .whereType<CustomerMapPoint>()
            .where(
              (p) =>
                  p.latitude.isFinite &&
                  p.longitude.isFinite &&
                  p.latitude.abs() <= 90 &&
                  p.longitude.abs() <= 180,
            )
            .map(
              (p) => mapbox.Point(
                coordinates: mapbox.Position(p.longitude, p.latitude),
              ),
            )
            .toList();
    final camera = await map.cameraForCoordinatesPadding(
      points,
      mapbox.CameraOptions(),
      mapbox.MbxEdgeInsets(top: 75, left: 35, bottom: 35, right: 35),
      15,
      null,
    );
    await map.easeTo(
      camera,
      mapbox.MapAnimationOptions(
        duration: animate ? _riderMoveDuration.inMilliseconds : 0,
      ),
    );
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
    final h =
        _sin2(dLat / 2) + math.cos(lat1) * math.cos(lat2) * _sin2(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  double _sin2(double value) => math.sin(value) * math.sin(value);

  @override
  Widget build(BuildContext context) {
    final rider = riderLocation;
    final center = rider != null && rider.hasCoordinates
        ? CustomerMapPoint(rider.latitude!, rider.longitude!)
        : widget.delivery.deliveryPoint ?? widget.delivery.pickupPoint;
    if (center == null) {
      return const InfoBanner(
        icon: Icons.location_off_outlined,
        text:
            'The rider’s live location will appear here once it is available.',
      );
    }
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
                zoom: 15,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text(
                    'Orange: rider • Blue: store • Green: delivery pin\n'
                    '${rider?.hasCoordinates == true ? "Rider location • updated ${rider?.recordedAt?.toLocal().toString().split(".").first ?? "time unavailable"}" : "Waiting for rider GPS"}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
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
