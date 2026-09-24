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
  MapLibreMapController? controller;
  Circle? pickupCircle;
  Circle? destinationCircle;
  Circle? riderCircle;
  bool styleLoaded = false;

  CustomerRiderLocation? get riderLocation =>
      widget.liveRiderLocation ?? widget.delivery.riderLocation;

  @override
  void didUpdateWidget(CustomerDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (styleLoaded) unawaited(_syncAnnotations());
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _syncAnnotations() async {
    final map = controller;
    if (map == null || !styleLoaded) return;
    pickupCircle = await _upsertCircle(
      map,
      pickupCircle,
      widget.delivery.pickupPoint,
      '#2563EB',
      8,
    );
    destinationCircle = await _upsertCircle(
      map,
      destinationCircle,
      widget.delivery.deliveryPoint,
      '#16A34A',
      9,
    );
    final rider = riderLocation;
    if (rider != null && rider.hasCoordinates) {
      riderCircle = await _upsertCircle(
        map,
        riderCircle,
        CustomerMapPoint(rider.latitude!, rider.longitude!),
        '#F97316',
        10,
      );
    }
  }

  Future<Circle?> _upsertCircle(
    MapLibreMapController map,
    Circle? circle,
    CustomerMapPoint? point,
    String color,
    double radius,
  ) async {
    if (point == null) return circle;
    final options = CircleOptions(
      geometry: LatLng(point.latitude, point.longitude),
      circleColor: color,
      circleRadius: radius,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 3,
    );
    if (circle == null) return map.addCircle(options);
    await map.updateCircle(circle, options);
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
    final palette = appPaletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 270,
        child: Stack(
          children: [
            MapLibreMap(
              styleString: CustomerMapConfig.fromEnvironment().styleUrl,
              initialCameraPosition: CameraPosition(
                target: LatLng(center.latitude, center.longitude),
                zoom: 13,
              ),
              compassEnabled: true,
              logoEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomRight,
              onMapCreated: (value) => controller = value,
              onStyleLoadedCallback: () {
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
