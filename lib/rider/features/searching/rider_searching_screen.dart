part of '../../app.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key, this.initialOffer});

  final RiderOffer? initialOffer;

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  RiderAppController? _controller;
  Timer? _clock;
  Timer? _offerRetry;
  Duration _onlineFor = Duration.zero;
  bool _navigating = false;
  int? _hiddenOfferId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = RiderDependencyScope.of(context).controller;
    if (_controller == controller) return;
    _controller?.removeListener(_onControllerChanged);
    _controller = controller..addListener(_onControllerChanged);
    _updateClock();
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_updateClock);
    });
    if (widget.initialOffer == null && controller.offers.isEmpty) {
      _offerRetry = Timer(
        const Duration(seconds: 3),
        controller.reconcileOffers,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncOperationalRoute(),
    );
  }

  void _updateClock() {
    final started = _controller?.onlineSince;
    _onlineFor = started == null
        ? Duration.zero
        : DateTime.now().difference(started);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(_updateClock);
    _syncOperationalRoute();
  }

  void _syncOperationalRoute() {
    if (!mounted || _navigating) return;
    final active = _controller?.activeDelivery;
    if (active == null) return;
    _navigating = true;
    final routes = RiderRouteScope.of(context)..startDelivery();
    routes.sync(_controller!);
    Navigator.of(context)
        .pushReplacementNamed(RiderRoutes.activeDelivery, arguments: active);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _offerRetry?.cancel();
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  RiderOffer? get _offer {
    final controller = _controller;
    if (controller == null) return widget.initialOffer;
    final requested = widget.initialOffer;
    if (requested != null) {
      final current = controller.offers
          .where((item) => item.id == requested.id)
          .firstOrNull;
      if (current != null) return current;
    }
    return controller.offers
        .where((item) => item.id != _hiddenOfferId)
        .firstOrNull;
  }

  Future<void> _goOffline() async {
    final controller = _controller!;
    if (controller.isSubmitting) return;
    final succeeded = await controller.setOnline(false);
    if (!mounted) return;
    if (!succeeded) {
      showMessage(
        context,
        controller.errorMessage ?? 'Could not end your shift.',
        kind: RiderToastKind.warning,
      );
      return;
    }
    RiderRouteScope.of(context).setOnline(false);
    Navigator.of(context)
        .pushNamedAndRemoveUntil(RiderRoutes.dashboard, (_) => false);
  }

  Future<void> _accept(RiderOffer offer) async {
    final delivery = await _controller!.accept(offer);
    if (!mounted) return;
    if (delivery == null) {
      showMessage(
        context,
        _controller!.errorMessage ?? 'Offer could not be accepted.',
        kind: RiderToastKind.warning,
      );
      return;
    }
    _syncOperationalRoute();
  }

  Future<void> _dismissOffer(RiderOffer offer, {required bool expired}) async {
    setState(() => _hiddenOfferId = offer.id);
    final succeeded = await _controller!.reject(offer);
    if (!mounted) return;
    if (!succeeded) setState(() => _hiddenOfferId = null);
    showMessage(
      context,
      succeeded
          ? expired
                ? 'Offer expired — still searching'
                : 'Offer skipped — still searching'
          : _controller!.errorMessage ?? 'Offer could not be dismissed.',
      kind: succeeded ? RiderToastKind.success : RiderToastKind.warning,
    );
    if (succeeded) {
      _offerRetry?.cancel();
      _offerRetry = Timer(
        const Duration(seconds: 3),
        _controller!.reconcileOffers,
      );
    }
  }

  String get _timerLabel {
    final minutes = _onlineFor.inMinutes.toString().padLeft(2, '0');
    final seconds = (_onlineFor.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final offer = _offer;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_goOffline());
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                _SearchingHero(
                  timer: _timerLabel,
                  earnings: controller.todayEarnings,
                  deliveries: controller.todayDeliveries,
                  onOffline: _goOffline,
                ),
                Expanded(
                  child: _RiderSearchingMap(
                    stores: controller.nearbyStores,
                    position: controller.riderPosition,
                    fallbackLatitude: controller.profile?.currentLatitude,
                    fallbackLongitude: controller.profile?.currentLongitude,
                  ),
                ),
              ],
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 194,
              left: 0,
              right: 0,
              child: const Center(child: _SearchingPill()),
            ),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? const Duration(milliseconds: 120)
                  : const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: offer == null
                  ? const SizedBox.shrink()
                  : Align(
                      key: ValueKey(offer.id),
                      alignment: Alignment.bottomCenter,
                      child: RiderIncomingOfferSheet(
                        offer: offer,
                        busy: controller.isSubmitting,
                        onAccept: () => _accept(offer),
                        onReject: () => _dismissOffer(offer, expired: false),
                        onExpired: () => _dismissOffer(offer, expired: true),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchingHero extends StatelessWidget {
  const _SearchingHero({
    required this.timer,
    required this.earnings,
    required this.deliveries,
    required this.onOffline,
  });

  final String timer;
  final double earnings;
  final int deliveries;
  final VoidCallback onOffline;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return RiderDuskHero(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _HeroRoundButton(
                    semanticLabel: 'Go offline and return to dashboard',
                    icon: Icons.arrow_back_rounded,
                    onTap: onOffline,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'You’re online',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: onPrimary),
                        ),
                        Text(
                          'Ready to receive deliveries',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: onPrimary.withValues(alpha: .72),
                              ),
                        ),
                      ],
                    ),
                  ),
                  _HeroRoundButton(
                    semanticLabel: 'Go offline, currently online',
                    icon: Icons.power_settings_new_rounded,
                    color: palette.success,
                    onTap: onOffline,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _HeroStat(label: 'ONLINE', value: timer),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroStat(
                      label: 'EARNINGS',
                      value: riderMoney(earnings),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroStat(label: 'DELIVERIES', value: '$deliveries'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroRoundButton extends StatelessWidget {
  const _HeroRoundButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: .18),
            shape: BoxShape.circle,
            border: Border.all(color: tint.withValues(alpha: .35)),
          ),
          child: Icon(icon, color: tint, size: 21),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: onPrimary.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: onPrimary, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onPrimary.withValues(alpha: .68),
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchingPill extends StatelessWidget {
  const _SearchingPill();

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: .1),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: palette.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Searching for deliveries…',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderSearchingMap extends StatefulWidget {
  const _RiderSearchingMap({
    required this.stores,
    required this.position,
    this.fallbackLatitude,
    this.fallbackLongitude,
  });

  final List<RiderStore> stores;
  final ValueListenable<RiderLatLng?>? position;
  final double? fallbackLatitude;
  final double? fallbackLongitude;

  @override
  State<_RiderSearchingMap> createState() => _RiderSearchingMapState();
}

class _RiderSearchingMapState extends State<_RiderSearchingMap>
    with SingleTickerProviderStateMixin {
  mapbox.MapboxMap? _map;
  mapbox.CircleAnnotationManager? _storeManager;
  bool _styleLoaded = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    widget.position?.addListener(_onPosition);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(_RiderSearchingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      oldWidget.position?.removeListener(_onPosition);
      widget.position?.addListener(_onPosition);
    }
    if (oldWidget.stores != widget.stores) unawaited(_syncStores());
  }

  @override
  void dispose() {
    widget.position?.removeListener(_onPosition);
    _pulse.dispose();
    super.dispose();
  }

  RiderLatLng? get _position =>
      widget.position?.value ??
      (widget.fallbackLatitude != null && widget.fallbackLongitude != null
          ? RiderLatLng(widget.fallbackLatitude!, widget.fallbackLongitude!)
          : null);

  RiderLatLng get _initialPosition {
    final current = _position;
    if (current != null) return current;
    final store = widget.stores
        .where((item) => item.hasCoordinates)
        .firstOrNull;
    if (store != null) return RiderLatLng(store.latitude!, store.longitude!);
    return const RiderLatLng(12.8797, 121.7740);
  }

  void _onPosition() {
    final position = _position;
    final map = _map;
    if (position == null || map == null) return;
    unawaited(
      map.easeTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position(position.longitude, position.latitude),
          ),
          zoom: 14,
        ),
        mapbox.MapAnimationOptions(duration: 500),
      ),
    );
  }

  Future<void> _syncStores() async {
    final manager = _storeManager;
    if (!_styleLoaded || manager == null) return;
    final color = riderPaletteOf(context).ratingStar.toARGB32();
    final surface = Theme.of(context).colorScheme.surface.toARGB32();
    await manager.deleteAll();
    for (final store in widget.stores.where((item) => item.hasCoordinates)) {
      await manager.create(
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(store.longitude!, store.latitude!),
          ),
          circleColor: color,
          circleRadius: 6,
          circleStrokeColor: surface,
          circleStrokeWidth: 2,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = RiderMapConfig.fromEnvironment();
    if (!config.isConfigured) {
      return const RiderEmptyState(
        icon: Icons.map_outlined,
        title: 'Mapbox is not configured',
        message: 'Add TALA_MAPBOX_ACCESS_TOKEN to your config file.',
      );
    }
    final initial = _initialPosition;
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        mapbox.MapWidget(
          key: const Key('rider-searching-map'),
          styleUri: config.styleUrl,
          viewport: mapbox.CameraViewportState(
            center: mapbox.Point(
              coordinates: mapbox.Position(initial.longitude, initial.latitude),
            ),
            zoom: 14,
          ),
          onMapCreated: (map) async {
            _map = map;
            _storeManager = await map.annotations
                .createCircleAnnotationManager();
            await map.location.updateSettings(
              mapbox.LocationComponentSettings(
                enabled: true,
                pulsingEnabled: false,
              ),
            );
            if (_styleLoaded) unawaited(_syncStores());
          },
          onStyleLoadedListener: (_) {
            _styleLoaded = true;
            unawaited(_syncStores());
          },
        ),
        IgnorePointer(
          child: Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                size: const Size.square(150),
                painter: _SearchPulsePainter(
                  progress: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : _pulse.value,
                  color: primary,
                  staticOnly: MediaQuery.disableAnimationsOf(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchPulsePainter extends CustomPainter {
  const _SearchPulsePainter({
    required this.progress,
    required this.color,
    required this.staticOnly,
  });

  final double progress;
  final Color color;
  final bool staticOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (staticOnly) {
      canvas.drawCircle(
        center,
        22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: .3),
      );
      return;
    }
    for (var index = 0; index < 3; index++) {
      final value = (progress + index / 3) % 1;
      final radius = 12 + (64 * Curves.easeOut.transform(value));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: .55 * (1 - value)),
      );
    }
  }

  @override
  bool shouldRepaint(_SearchPulsePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      staticOnly != oldDelegate.staticOnly;
}
