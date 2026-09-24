part of '../../../app.dart';

class RiderDeliveryMap extends StatefulWidget {
  const RiderDeliveryMap({super.key, required this.delivery});

  final RiderDelivery delivery;

  @override
  State<RiderDeliveryMap> createState() => _RiderDeliveryMapState();
}

class _RiderDeliveryMapState extends State<RiderDeliveryMap> {
  MapLibreMapController? controller;
  bool styleLoaded = false;

  bool get hasPickup =>
      widget.delivery.pickupLatitude != null &&
      widget.delivery.pickupLongitude != null;
  bool get hasDestination =>
      widget.delivery.deliveryLatitude != null &&
      widget.delivery.deliveryLongitude != null;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _addStops() async {
    final map = controller;
    if (map == null || !styleLoaded) return;
    if (hasPickup) {
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(
            widget.delivery.pickupLatitude!,
            widget.delivery.pickupLongitude!,
          ),
          circleColor: '#2563EB',
          circleRadius: 9,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    }
    if (hasDestination) {
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(
            widget.delivery.deliveryLatitude!,
            widget.delivery.deliveryLongitude!,
          ),
          circleColor: '#16A34A',
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPickup && !hasDestination) {
      return const RiderEmptyState(
        icon: Icons.location_off_outlined,
        title: 'Map unavailable',
        message: 'This delivery does not have valid map coordinates.',
      );
    }
    final latitude = hasDestination
        ? widget.delivery.deliveryLatitude!
        : widget.delivery.pickupLatitude!;
    final longitude = hasDestination
        ? widget.delivery.deliveryLongitude!
        : widget.delivery.pickupLongitude!;
    final palette = riderPaletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            MapLibreMap(
              styleString: RiderMapConfig.fromEnvironment().styleUrl,
              initialCameraPosition: CameraPosition(
                target: LatLng(latitude, longitude),
                zoom: 13,
              ),
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              compassEnabled: true,
              logoEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomRight,
              onMapCreated: (value) => controller = value,
              onStyleLoadedCallback: () {
                styleLoaded = true;
                unawaited(_addStops());
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
                    'Blue: pickup  •  Green: customer',
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
