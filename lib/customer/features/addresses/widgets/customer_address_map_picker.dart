part of '../../../app.dart';

typedef CustomerAddressMapSurfaceBuilder = Widget Function(
  CustomerMapPoint center,
  CustomerMapPoint? selectedPoint,
  ValueChanged<CustomerMapPoint> onSelect,
);

class CustomerAddressMapPicker extends StatefulWidget {
  const CustomerAddressMapPicker({
    super.key,
    required this.onChanged,
    this.selectedPoint,
    this.surfaceBuilder,
  });

  final CustomerMapPoint? selectedPoint;
  final ValueChanged<CustomerMapPoint> onChanged;
  final CustomerAddressMapSurfaceBuilder? surfaceBuilder;

  @override
  State<CustomerAddressMapPicker> createState() =>
      _CustomerAddressMapPickerState();
}

class _CustomerAddressMapPickerState extends State<CustomerAddressMapPicker> {
  static const fallbackCenter = CustomerMapPoint(15.4865, 120.9734);

  MapLibreMapController? controller;
  Circle? pin;
  bool styleLoaded = false;

  @override
  void didUpdateWidget(CustomerAddressMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (styleLoaded && oldWidget.selectedPoint != widget.selectedPoint) {
      unawaited(_syncPin());
    }
  }

  Future<void> _syncPin() async {
    final map = controller;
    final point = widget.selectedPoint;
    if (map == null || !styleLoaded || point == null) return;
    final options = CircleOptions(
      geometry: LatLng(point.latitude, point.longitude),
      circleColor: '#F97316',
      circleRadius: 11,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 4,
    );
    if (pin == null) {
      pin = await map.addCircle(options);
    } else {
      await map.updateCircle(pin!, options);
    }
  }

  void _select(LatLng coordinates) {
    widget.onChanged(
      CustomerMapPoint(coordinates.latitude, coordinates.longitude),
    );
  }

  Widget _buildMap(CustomerMapPoint point) {
    final surfaceBuilder = widget.surfaceBuilder;
    if (surfaceBuilder != null) {
      return surfaceBuilder(point, widget.selectedPoint, widget.onChanged);
    }
    return MapLibreMap(
      key: const Key('address-map'),
      styleString: CustomerMapConfig.fromEnvironment().styleUrl,
      initialCameraPosition: CameraPosition(
        target: LatLng(point.latitude, point.longitude),
        zoom: widget.selectedPoint == null ? 12 : 16,
      ),
      compassEnabled: true,
      logoEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
      onMapClick: (_, coordinates) => _select(coordinates),
      onMapCreated: (value) => controller = value,
      onStyleLoadedCallback: () {
        styleLoaded = true;
        unawaited(_syncPin());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.selectedPoint ?? fallbackCenter;
    final palette = appPaletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                _buildMap(point),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 10,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.touch_app_rounded, color: sky, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap the map to pin the exact delivery entrance.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.selectedPoint == null
              ? 'No delivery pin selected.'
              : 'Pin: ${widget.selectedPoint!.latitude.toStringAsFixed(6)}, '
                    '${widget.selectedPoint!.longitude.toStringAsFixed(6)}',
          key: const Key('address-map-selection'),
          style: TextStyle(color: palette.quiet, fontSize: 12),
        ),
      ],
    );
  }
}
