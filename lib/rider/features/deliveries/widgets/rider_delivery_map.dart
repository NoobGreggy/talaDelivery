part of '../../../app.dart';

class RiderDeliveryMap extends StatefulWidget {
  const RiderDeliveryMap({
    super.key,
    required this.delivery,
    required this.stage,
    this.riderPosition,
  });

  final RiderDelivery delivery;
  final DeliveryStage stage;
  final ValueListenable<RiderLatLng?>? riderPosition;

  @override
  State<RiderDeliveryMap> createState() => _RiderDeliveryMapState();
}

class _RiderDeliveryMapState extends State<RiderDeliveryMap> {
  mapbox.MapboxMap? _map;
  mapbox.CircleAnnotationManager? _circleManager;
  mapbox.PolylineAnnotationManager? _lineManager;
  final Map<String, mapbox.CircleAnnotation> _markers = {};
  final RiderRoadRoutes _routes = RiderRoadRoutes();
  DateTime? _lastRouteAt;
  RiderLatLng? _routeDestination;
  bool _routeInFlight = false;
  bool _routeUnavailable = false;
  bool _syncing = false;
  int _routeGeneration = 0;
  mapbox.PolylineAnnotation? _routeLine;
  bool _styleLoaded = false;

  bool get _storePhase =>
      widget.stage == DeliveryStage.toStore ||
      widget.stage == DeliveryStage.atStore;

  RiderLatLng? get _rider => widget.riderPosition?.value;

  RiderLatLng? get _destination {
    return RiderNavigation.destination(widget.delivery, widget.stage);
  }

  @override
  void initState() {
    super.initState();
    widget.riderPosition?.addListener(_onRiderPosition);
  }

  @override
  void didUpdateWidget(RiderDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.riderPosition != widget.riderPosition) {
      oldWidget.riderPosition?.removeListener(_onRiderPosition);
      widget.riderPosition?.addListener(_onRiderPosition);
    }
    if (oldWidget.stage != widget.stage ||
        oldWidget.delivery.id != widget.delivery.id) {
      unawaited(_syncMap(animateDestination: true));
    }
  }

  @override
  void dispose() {
    _routeGeneration++;
    _routes.dispose();
    widget.riderPosition?.removeListener(_onRiderPosition);
    super.dispose();
  }

  void _onRiderPosition() => unawaited(_syncMap());

  Future<void> _syncMap({bool animateDestination = false}) async {
    if (!mounted || _syncing) return;
    _syncing = true;
    try {
      await _syncMapInner(animateDestination: animateDestination);
    } catch (_) {
      // Native map may be torn down during a network/GPS update.
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pin(String key, RiderLatLng? point, int color) async {
    if (point == null ||
        !RiderNavigation.valid(point) ||
        _circleManager == null) {
      return;
    }
    final options = mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(point.longitude, point.latitude),
      ),
      circleColor: color,
      circleRadius: key == 'rider' ? 8 : 10,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3,
    );
    final marker = _markers[key];
    if (marker == null) {
      _markers[key] = await _circleManager!.create(options);
    } else {
      marker
        ..geometry = options.geometry
        ..circleColor = color;
      await _circleManager!.update(marker);
    }
  }

  Future<void> _syncMapInner({bool animateDestination = false}) async {
    final map = _map;
    final circleManager = _circleManager;
    final lineManager = _lineManager;
    final destination = _destination;
    if (!_styleLoaded ||
        map == null ||
        circleManager == null ||
        lineManager == null ||
        destination == null) {
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    await _pin(
      'store',
      RiderNavigation.destination(widget.delivery, DeliveryStage.toStore),
      0xFF2563EB,
    );
    await _pin(
      'customer',
      RiderNavigation.destination(widget.delivery, DeliveryStage.toCustomer),
      0xFF16A34A,
    );
    final rider = _rider;
    if (rider != null) {
      await _pin('rider', rider, 0xFFF97316);
      unawaited(_syncRoadRoute(rider, destination, scheme.primary.toARGB32()));
    }

    if (animateDestination) {
      final points =
          [
                _rider,
                RiderNavigation.destination(
                  widget.delivery,
                  DeliveryStage.toStore,
                ),
                RiderNavigation.destination(
                  widget.delivery,
                  DeliveryStage.toCustomer,
                ),
              ]
              .whereType<RiderLatLng>()
              .where(RiderNavigation.valid)
              .map(
                (point) => mapbox.Point(
                  coordinates: mapbox.Position(point.longitude, point.latitude),
                ),
              )
              .toList();
      final camera = await map.cameraForCoordinatesPadding(
        points,
        mapbox.CameraOptions(),
        mapbox.MbxEdgeInsets(top: 85, left: 35, bottom: 35, right: 35),
        15,
        null,
      );
      await map.easeTo(
        camera,
        mapbox.MapAnimationOptions(duration: reduceMotion ? 100 : 500),
      );
    }
  }

  Future<void> _syncRoadRoute(
    RiderLatLng rider,
    RiderLatLng destination,
    int color,
  ) async {
    final changed =
        _routeDestination?.latitude != destination.latitude ||
        _routeDestination?.longitude != destination.longitude;
    if (changed) {
      _routeGeneration++;
      _routeDestination = destination;
      _lastRouteAt = null;
      _routeInFlight = false;
      await _clearRouteLine();
    }
    if (!mounted ||
        _routeInFlight ||
        (_lastRouteAt != null &&
            DateTime.now().difference(_lastRouteAt!) <
                const Duration(seconds: 30))) {
      return;
    }
    _lastRouteAt = DateTime.now();
    _routeInFlight = true;
    final generation = _routeGeneration;
    try {
      final coordinates = await _routes.driving(
        rider,
        destination,
        RiderMapConfig.fromEnvironment().accessToken,
      );
      if (!mounted || generation != _routeGeneration || _lineManager == null) {
        return;
      }
      setState(() => _routeUnavailable = coordinates.isEmpty);
      if (coordinates.isEmpty) {
        await _clearRouteLine();
        return;
      }
      final geometry = mapbox.LineString(coordinates: coordinates);
      if (_routeLine == null) {
        _routeLine = await _lineManager!.create(
          mapbox.PolylineAnnotationOptions(
            geometry: geometry,
            lineColor: color,
            lineWidth: 4,
          ),
        );
      } else {
        _routeLine!
          ..geometry = geometry
          ..lineColor = color;
        await _lineManager!.update(_routeLine!);
      }
    } catch (_) {
      if (mounted && generation == _routeGeneration) {
        setState(() => _routeUnavailable = true);
        await _clearRouteLine();
      }
    } finally {
      if (generation == _routeGeneration) _routeInFlight = false;
    }
  }

  Future<void> _clearRouteLine() async {
    final old = _routeLine;
    _routeLine = null;
    if (old == null) return;
    try {
      await _lineManager?.delete(old);
    } catch (_) {
      /* Native map may already be disposed. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    if (destination == null) {
      return const RiderEmptyState(
        icon: Icons.location_off_outlined,
        title: 'Map unavailable',
        message: 'The current destination does not have valid coordinates.',
      );
    }
    final config = RiderMapConfig.fromEnvironment();
    if (!config.isConfigured) {
      return const RiderEmptyState(
        icon: Icons.map_outlined,
        title: 'Mapbox is not configured',
        message: 'Add TALA_MAPBOX_ACCESS_TOKEN to your config file.',
      );
    }
    final rider = _rider;
    final latitude = rider == null
        ? destination.latitude
        : (rider.latitude + destination.latitude) / 2;
    final longitude = rider == null
        ? destination.longitude
        : (rider.longitude + destination.longitude) / 2;
    final palette = riderPaletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            mapbox.MapWidget(
              key: ValueKey('delivery-map-${widget.delivery.id}'),
              styleUri: config.styleUrl,
              viewport: mapbox.CameraViewportState(
                center: mapbox.Point(
                  coordinates: mapbox.Position(longitude, latitude),
                ),
                zoom: 13.5,
              ),
              onMapCreated: (value) async {
                _map = value;
                _circleManager = await value.annotations
                    .createCircleAnnotationManager();
                _lineManager = await value.annotations
                    .createPolylineAnnotationManager();
                if (_styleLoaded) unawaited(_syncMap(animateDestination: true));
              },
              onStyleLoadedListener: (_) {
                _styleLoaded = true;
                unawaited(_syncMap(animateDestination: true));
              },
            ),
            Positioned(
              left: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text(
                    'Blue: store • Green: customer • Orange: you\n'
                    '${_storePhase ? "Route: pickup store" : "Route: customer"}'
                    '${_routeUnavailable ? "\nRoad route unavailable. Use Maps below." : ""}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
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
