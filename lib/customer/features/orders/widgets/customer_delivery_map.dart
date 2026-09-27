part of '../../../app.dart';

class CustomerDeliveryMap extends StatefulWidget {
  const CustomerDeliveryMap({
    super.key,
    required this.delivery,
    this.liveRiderLocation,
  });

  final CustomerDelivery delivery;
  final CustomerRiderLocation? liveRiderLocation;

  @override
  State<CustomerDeliveryMap> createState() => _CustomerDeliveryMapState();
}

class _CustomerDeliveryMapState extends State<CustomerDeliveryMap> {
  mapbox.MapboxMap? controller;
  mapbox.CircleAnnotationManager? circleManager;
  mapbox.CircleAnnotation? pickupCircle;
  mapbox.CircleAnnotation? destinationCircle;
  mapbox.CircleAnnotation? riderCircle;
  bool styleLoaded = false;

  CustomerRiderLocation? get riderLocation =>
      widget.liveRiderLocation ?? widget.delivery.riderLocation;

  @override
  void didUpdateWidget(CustomerDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (styleLoaded) unawaited(_syncAnnotations());
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
      riderCircle = await _upsertCircle(
        map,
        riderCircle,
        CustomerMapPoint(rider.latitude!, rider.longitude!),
        0xFFF97316,
        10,
      );
    }
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
