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
  mapbox.CircleAnnotation? _destinationMarker;
  mapbox.PolylineAnnotation? _routeLine;
  bool _styleLoaded = false;

  bool get _storePhase =>
      widget.stage == DeliveryStage.toStore ||
      widget.stage == DeliveryStage.atStore;

  RiderLatLng? get _rider => widget.riderPosition?.value;

  RiderLatLng? get _destination {
    if (_storePhase &&
        widget.delivery.pickupLatitude != null &&
        widget.delivery.pickupLongitude != null) {
      return RiderLatLng(
        widget.delivery.pickupLatitude!,
        widget.delivery.pickupLongitude!,
      );
    }
    if (!_storePhase &&
        widget.delivery.deliveryLatitude != null &&
        widget.delivery.deliveryLongitude != null) {
      return RiderLatLng(
        widget.delivery.deliveryLatitude!,
        widget.delivery.deliveryLongitude!,
      );
    }
    return null;
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
    widget.riderPosition?.removeListener(_onRiderPosition);
    super.dispose();
  }

  void _onRiderPosition() => unawaited(_syncMap());

  Future<void> _syncMap({bool animateDestination = false}) async {
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
    final palette = riderPaletteOf(context);
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final destinationColor = _storePhase ? scheme.primary : palette.ratingStar;
    final markerOptions = mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(
          destination.longitude,
          destination.latitude,
        ),
      ),
      circleColor: destinationColor.toARGB32(),
      circleRadius: 10,
      circleStrokeColor: scheme.surface.toARGB32(),
      circleStrokeWidth: 3,
    );
    if (_destinationMarker == null) {
      _destinationMarker = await circleManager.create(markerOptions);
    } else {
      _destinationMarker!
        ..geometry = markerOptions.geometry
        ..circleColor = markerOptions.circleColor;
      await circleManager.update(_destinationMarker!);
    }

    final rider = _rider;
    if (rider != null) {
      final lineOptions = mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(
          coordinates: [
            mapbox.Position(rider.longitude, rider.latitude),
            mapbox.Position(destination.longitude, destination.latitude),
          ],
        ),
        lineColor: destinationColor.toARGB32(),
        lineWidth: 4,
        lineOpacity: .82,
      );
      if (_routeLine == null) {
        _routeLine = await lineManager.create(lineOptions);
      } else {
        _routeLine!
          ..geometry = lineOptions.geometry
          ..lineColor = lineOptions.lineColor;
        await lineManager.update(_routeLine!);
      }
    }

    if (animateDestination) {
      await map.easeTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position(
              destination.longitude,
              destination.latitude,
            ),
          ),
          zoom: 14,
        ),
        mapbox.MapAnimationOptions(duration: reduceMotion ? 100 : 500),
      );
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
                await value.location.updateSettings(
                  mapbox.LocationComponentSettings(enabled: true),
                );
                if (_styleLoaded) unawaited(_syncMap());
              },
              onStyleLoadedListener: (_) {
                _styleLoaded = true;
                unawaited(_syncMap());
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
                    _storePhase
                        ? 'Destination: pickup store'
                        : 'Destination: customer',
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
