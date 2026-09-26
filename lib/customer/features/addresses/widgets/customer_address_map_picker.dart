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
    this.locationService,
    this.reverseGeocoder,
    this.onAddressResolved,
  });

  final CustomerMapPoint? selectedPoint;
  final ValueChanged<CustomerMapPoint> onChanged;
  final CustomerAddressMapSurfaceBuilder? surfaceBuilder;
  final CustomerLocationService? locationService;
  final CustomerReverseGeocoder? reverseGeocoder;
  final ValueChanged<CustomerResolvedAddress>? onAddressResolved;

  @override
  State<CustomerAddressMapPicker> createState() =>
      _CustomerAddressMapPickerState();
}

class _CustomerAddressMapPickerState extends State<CustomerAddressMapPicker> {
  static const fallbackCenter = CustomerMapPoint(15.4865, 120.9734);

  MapLibreMapController? controller;
  Circle? pin;
  bool styleLoaded = false;
  bool locating = false;
  bool resolvingAddress = false;
  String? locationMessage;
  String? accuracyMessage;
  int reverseRequest = 0;

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

  Future<void> _selectPoint(
    CustomerMapPoint point, {
    bool moveCamera = false,
  }) async {
    widget.onChanged(point);
    if (moveCamera) {
      await controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), 17),
      );
    }
    await _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(CustomerMapPoint point) async {
    final geocoder = widget.reverseGeocoder;
    if (geocoder == null) return;
    final request = ++reverseRequest;
    setState(() {
      resolvingAddress = true;
      locationMessage = 'Finding the readable address…';
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || request != reverseRequest) return;
    try {
      final address = await geocoder.reverse(point);
      if (!mounted || request != reverseRequest) return;
      widget.onAddressResolved?.call(address);
      setState(() {
        resolvingAddress = false;
        locationMessage = address.formattedAddress.isEmpty
            ? 'Location selected. Review the address fields below.'
            : address.formattedAddress;
      });
    } catch (_) {
      if (!mounted || request != reverseRequest) return;
      setState(() {
        resolvingAddress = false;
        locationMessage =
            'Location selected. We could not fill the address automatically; '
            'please enter it manually.';
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    final location = widget.locationService;
    if (location == null || locating) return;
    setState(() {
      locating = true;
      locationMessage = 'Getting your current location…';
    });
    final result = await location.currentLocation();
    if (!mounted) return;
    setState(() => locating = false);

    switch (result.status) {
      case CustomerLocationStatus.available:
        final point = result.point;
        if (point == null) return;
        setState(() {
          accuracyMessage = result.isApproximate
              ? 'Your device provided an approximate location. Adjust the pin '
                    'on the map if needed.'
              : null;
          locationMessage = 'Current location found. Review or adjust the pin.';
        });
        await _selectPoint(point, moveCamera: true);
      case CustomerLocationStatus.permissionDenied:
        setState(() {
          locationMessage =
              'Location permission was not granted. Enter the address manually '
              'or select it on the map.';
        });
      case CustomerLocationStatus.permissionPermanentlyDenied:
        setState(() {
          locationMessage =
              'Location access is blocked in device settings. Enter the address '
              'manually or select it on the map.';
        });
      case CustomerLocationStatus.servicesDisabled:
        setState(() {
          locationMessage =
              'Location services are turned off. Enable them or select the '
              'address manually.';
        });
      case CustomerLocationStatus.unavailable:
        setState(() {
          locationMessage =
              'We could not get your location. Enter the address manually or '
              'select it on the map.';
        });
    }
  }

  Widget _buildMap(CustomerMapPoint point) {
    final surfaceBuilder = widget.surfaceBuilder;
    if (surfaceBuilder != null) {
      return surfaceBuilder(
        point,
        widget.selectedPoint,
        (selected) => unawaited(_selectPoint(selected)),
      );
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
      onMapClick: (_, coordinates) => unawaited(
        _selectPoint(
          CustomerMapPoint(coordinates.latitude, coordinates.longitude),
        ),
      ),
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
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Use your current location?',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'We can use it once to help fill your delivery address. '
                  'Permission is requested only after you choose this option.',
                  style: TextStyle(color: palette.quiet, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('address-use-current-location'),
                      onPressed: locating || widget.locationService == null
                          ? null
                          : _useCurrentLocation,
                      icon: locating
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Use current location'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('address-enter-manually'),
                      onPressed: () => setState(() {
                        locationMessage =
                            'Enter the address below and tap the map to set the '
                            'exact delivery point.';
                      }),
                      icon: const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 18,
                      ),
                      label: const Text('Enter manually'),
                    ),
                  ],
                ),
                if (locationMessage != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (resolvingAddress)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        const Icon(Icons.info_outline_rounded, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationMessage!,
                          key: const Key('address-location-message'),
                          style: TextStyle(color: palette.quiet, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (accuracyMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    accuracyMessage!,
                    key: const Key('address-location-accuracy-warning'),
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
