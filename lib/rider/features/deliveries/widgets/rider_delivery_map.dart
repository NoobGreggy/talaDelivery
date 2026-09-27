part of '../../../app.dart';

class RiderDeliveryMap extends StatefulWidget {
  const RiderDeliveryMap({super.key, required this.delivery});

  final RiderDelivery delivery;

  @override
  State<RiderDeliveryMap> createState() => _RiderDeliveryMapState();
}

class _RiderDeliveryMapState extends State<RiderDeliveryMap> {
  mapbox.MapboxMap? controller;
  mapbox.CircleAnnotationManager? circleManager;
  bool styleLoaded = false;
  bool addingStops = false;
  bool stopsAdded = false;

  bool get hasPickup =>
      widget.delivery.pickupLatitude != null &&
      widget.delivery.pickupLongitude != null;
  bool get hasDestination =>
      widget.delivery.deliveryLatitude != null &&
      widget.delivery.deliveryLongitude != null;

  Future<void> _addStops() async {
    final manager = circleManager;
    if (manager == null || !styleLoaded || addingStops || stopsAdded) return;
    addingStops = true;
    try {
      if (hasPickup) {
        await manager.create(
          mapbox.CircleAnnotationOptions(
            geometry: mapbox.Point(
              coordinates: mapbox.Position(
                widget.delivery.pickupLongitude!,
                widget.delivery.pickupLatitude!,
              ),
            ),
            circleColor: 0xFF2563EB,
            circleRadius: 9,
            circleStrokeColor: 0xFFFFFFFF,
            circleStrokeWidth: 3,
          ),
        );
      }
      if (hasDestination) {
        await manager.create(
          mapbox.CircleAnnotationOptions(
            geometry: mapbox.Point(
              coordinates: mapbox.Position(
                widget.delivery.deliveryLongitude!,
                widget.delivery.deliveryLatitude!,
              ),
            ),
            circleColor: 0xFF16A34A,
            circleRadius: 10,
            circleStrokeColor: 0xFFFFFFFF,
            circleStrokeWidth: 3,
          ),
        );
      }
      stopsAdded = true;
    } finally {
      addingStops = false;
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
    final mapConfig = RiderMapConfig.fromEnvironment();
    if (!mapConfig.isConfigured) {
      return const RiderEmptyState(
        icon: Icons.map_outlined,
        title: 'Mapbox is not configured',
        message: 'Add TALA_MAPBOX_ACCESS_TOKEN to your config file.',
      );
    }
    final palette = riderPaletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            mapbox.MapWidget(
              styleUri: mapConfig.styleUrl,
              viewport: mapbox.CameraViewportState(
                center: mapbox.Point(
                  coordinates: mapbox.Position(longitude, latitude),
                ),
                zoom: 13,
              ),
              onMapCreated: (value) async {
                controller = value;
                circleManager = await value.annotations
                    .createCircleAnnotationManager();
                if (styleLoaded) unawaited(_addStops());
                await value.location.updateSettings(
                  mapbox.LocationComponentSettings(enabled: true),
                );
              },
              onStyleLoadedListener: (_) {
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
