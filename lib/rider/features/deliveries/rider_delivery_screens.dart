part of '../../app.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key, this.delivery});

  final RiderDelivery? delivery;

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final Set<int> _checkedItemIds = {};
  bool _cashReceived = false;
  RiderAppController? _controller;
  int? _deliveryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = RiderDependencyScope.of(context).controller;
    if (_controller != next) {
      _controller?.removeListener(_onDeliveryChanged);
      _controller = next..addListener(_onDeliveryChanged);
    }
    final id = delivery?.id;
    if (_deliveryId != id) {
      _deliveryId = id;
      _checkedItemIds.clear();
      _cashReceived = false;
    }
  }

  void _onDeliveryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onDeliveryChanged);
    super.dispose();
  }

  RiderDelivery? get delivery {
    final controller = _controller;
    if (controller == null) return widget.delivery;
    final initial = widget.delivery;
    if (initial == null) return controller.activeDelivery;
    return controller.deliveries
            .where((item) => item.id == initial.id)
            .firstOrNull ??
        (controller.activeDelivery?.id == initial.id
            ? controller.activeDelivery
            : null) ??
        initial;
  }

  DeliveryStage _stageFor(String status) => switch (status) {
    'ASSIGNED' => DeliveryStage.toStore,
    'ACCEPTED' => DeliveryStage.atStore,
    'PICKED_UP' => DeliveryStage.toCustomer,
    'IN_TRANSIT' => DeliveryStage.atCustomer,
    _ => DeliveryStage.toStore,
  };

  String _titleFor(RiderDelivery delivery, DeliveryStage stage) {
    if (!delivery.isActive) {
      return delivery.status.replaceAll('_', ' ').toLowerCase();
    }
    return switch (stage) {
      DeliveryStage.toStore => 'Heading to store',
      DeliveryStage.atStore => 'At the store',
      DeliveryStage.toCustomer => 'Heading to customer',
      DeliveryStage.atCustomer => 'At the customer',
    };
  }

  String _buttonFor(DeliveryStage stage) => switch (stage) {
    DeliveryStage.toStore => 'Arrived at store',
    DeliveryStage.atStore => 'Confirm pickup',
    DeliveryStage.toCustomer => 'Arrived at customer',
    DeliveryStage.atCustomer => 'Mark as delivered',
  };

  String _actionFor(DeliveryStage stage) => switch (stage) {
    DeliveryStage.toStore => 'arrived',
    DeliveryStage.atStore => 'pickup',
    DeliveryStage.toCustomer => 'start',
    DeliveryStage.atCustomer => 'complete',
  };

  bool _canAdvance(RiderDelivery delivery, DeliveryStage stage) {
    if (!delivery.isActive || (_controller?.isSubmitting ?? false)) {
      return false;
    }
    if (stage == DeliveryStage.atStore) {
      return delivery.order?.items.every(
            (item) => _checkedItemIds.contains(item.id),
          ) ??
          true;
    }
    if (stage == DeliveryStage.atCustomer &&
        delivery.order?.paymentMethod.toUpperCase() == 'COD') {
      return _cashReceived;
    }
    return true;
  }

  Future<void> _advance(RiderDelivery value, DeliveryStage stage) async {
    if (!_canAdvance(value, stage)) return;
    final updated = await _controller!.advanceDelivery(_actionFor(stage));
    if (!mounted) return;
    if (updated == null) {
      showMessage(
        context,
        _controller!.errorMessage ?? 'Delivery could not be updated.',
        kind: RiderToastKind.warning,
      );
      return;
    }
    if (updated.isDelivered) {
      RiderRouteScope.of(context).completeDelivery();
      await Future<void>.delayed(
        MediaQuery.disableAnimationsOf(context)
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 400),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(RiderRoutes.deliveryComplete, arguments: updated);
      return;
    }
    RiderRouteScope.of(context).sync(_controller!);
    showMessage(
      context,
      'Delivery status updated.',
      kind: RiderToastKind.success,
    );
  }

  Future<void> _navigate(
    RiderDelivery value,
    DeliveryStage stage, {
    required bool apple,
  }) async {
    final destination = RiderNavigation.destination(value, stage);
    if (destination == null) {
      showMessage(context, 'This destination has no valid map pin.');
      return;
    }
    try {
      final uri = apple
          ? RiderNavigation.appleMaps(destination)
          : RiderNavigation.googleMaps(destination);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // A missing external app must not interrupt the delivery workflow.
    }
    if (mounted) {
      showMessage(
        context,
        'Unable to open Maps. Please install a maps app and try again.',
      );
    }
  }

  Future<void> _contact(String? phone, {required bool message}) async {
    if (phone == null || phone.trim().isEmpty) {
      showMessage(context, 'No contact number is available for this stop.');
      return;
    }
    final uri = Uri(scheme: message ? 'sms' : 'tel', path: phone.trim());
    if (!await launchUrl(uri) && mounted) {
      showMessage(
        context,
        message ? 'Messaging is unavailable.' : 'Calling is unavailable.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = delivery;
    if (value == null) {
      return const Scaffold(
        body: RiderEmptyState(
          icon: Icons.route_outlined,
          title: 'No active delivery',
          message: 'Accept an offer before opening this page.',
        ),
      );
    }
    final stage = _stageFor(value.status);
    final palette = riderPaletteOf(context);
    final storePhase =
        stage == DeliveryStage.toStore || stage == DeliveryStage.atStore;
    final contactName = storePhase
        ? value.store?.name ?? 'Pickup store'
        : value.order?.customerName ?? 'Customer';
    final contactAddress = storePhase
        ? value.pickupAddress
        : value.deliveryAddress;
    final phone = storePhase ? value.store?.phone : value.order?.customerPhone;
    return Scaffold(
      body: Column(
        children: [
          _DeliveryStageHero(
            title: _titleFor(value, stage),
            orderNumber: value.displayNumber,
            stage: stage,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                RiderDeliveryMap(
                  delivery: value,
                  stage: stage,
                  riderPosition: _controller?.riderPosition,
                ),
                const SizedBox(height: 16),
                if (value.isActive) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.navigation_outlined),
                        label: Text(
                          'Google Maps: ${storePhase ? "pickup" : "customer"}',
                        ),
                        onPressed: () => _navigate(value, stage, apple: false),
                      ),
                      if (defaultTargetPlatform == TargetPlatform.iOS)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Apple Maps'),
                          onPressed: () => _navigate(value, stage, apple: true),
                        ),
                    ],
                  ),
                  const Text(
                    'Location sharing stays on during this delivery when you open Maps or lock the screen. Keep Tala running and allow location access.',
                  ),
                  TextButton.icon(
                    onPressed: () => Geolocator.openAppSettings(),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Location settings'),
                  ),
                  const SizedBox(height: 16),
                ],
                _DeliveryContactCard(
                  pickup: storePhase,
                  name: contactName,
                  address: contactAddress,
                  distanceKm: value.distanceKm,
                  onCall: () => _contact(phone, message: false),
                  onMessage: () => _contact(phone, message: true),
                ),
                if (stage == DeliveryStage.atStore) ...[
                  const SizedBox(height: 16),
                  _OrderChecklist(
                    items: value.order?.items ?? const [],
                    checkedIds: _checkedItemIds,
                    onChanged: (id, checked) => setState(() {
                      if (checked) {
                        _checkedItemIds.add(id);
                      } else {
                        _checkedItemIds.remove(id);
                      }
                    }),
                  ),
                ],
                if (stage == DeliveryStage.atCustomer &&
                    value.order?.paymentMethod.toUpperCase() == 'COD') ...[
                  const SizedBox(height: 16),
                  _CodConfirmationCard(
                    amount: value.order?.total ?? 0,
                    confirmed: _cashReceived,
                    onConfirm: () => setState(() => _cashReceived = true),
                  ),
                ],
                if (value.order?.notes != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text(value.order!.notes!)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          _DeliveryActionPanel(
            payout: value.riderCommission,
            buttonLabel: _controller!.isSubmitting
                ? 'Updating…'
                : _buttonFor(stage),
            onPressed: _canAdvance(value, stage)
                ? () => _advance(value, stage)
                : null,
          ),
        ],
      ),
    );
  }
}

class _DeliveryStageHero extends StatelessWidget {
  const _DeliveryStageHero({
    required this.title,
    required this.orderNumber,
    required this.stage,
  });

  final String title;
  final String orderNumber;
  final DeliveryStage stage;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final palette = riderPaletteOf(context);
    return RiderDuskHero(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: onPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                orderNumber,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: onPrimary.withValues(alpha: .7)),
              ),
              const SizedBox(height: 16),
              Row(
                children: List.generate(4, (index) {
                  final current = stage.index;
                  final color = index < current
                      ? palette.success
                      : index == current
                      ? onPrimary
                      : onPrimary.withValues(alpha: .22);
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryContactCard extends StatelessWidget {
  const _DeliveryContactCard({
    required this.pickup,
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.onCall,
    required this.onMessage,
  });

  final bool pickup;
  final String name;
  final String address;
  final double distanceKm;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup ? 'PICKUP' : 'DROP-OFF',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(
                  '${address.isEmpty ? 'Address unavailable' : address} · ${distanceKm.toStringAsFixed(1)} km',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ContactButton(
            icon: Icons.call_outlined,
            label: 'Call',
            onTap: onCall,
          ),
          const SizedBox(width: 6),
          _ContactButton(
            icon: Icons.message_outlined,
            label: 'Message',
            onTap: onMessage,
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: IconButton.filledTonal(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onTap,
      icon: Icon(icon, size: 20),
    ),
  );
}

class _OrderChecklist extends StatelessWidget {
  const _OrderChecklist({
    required this.items,
    required this.checkedIds,
    required this.onChanged,
  });

  final List<RiderOrderItem> items;
  final Set<int> checkedIds;
  final void Function(int id, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check order items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(
              'No item checklist was provided for this order.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...items.map((item) {
              final checked = checkedIds.contains(item.id);
              return Semantics(
                checked: checked,
                label: item.checklistLabel,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: checked,
                  onChanged: (value) => onChanged(item.id, value ?? false),
                  title: Text(
                    item.checklistLabel,
                    style: TextStyle(
                      color: checked ? palette.muted : palette.text,
                      decoration: checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CodConfirmationCard extends StatelessWidget {
  const _CodConfirmationCard({
    required this.amount,
    required this.confirmed,
    required this.onConfirm,
  });

  final double amount;
  final bool confirmed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    final color = confirmed ? palette.success : palette.ratingStar;
    return Semantics(
      button: !confirmed,
      label:
          'Cash on delivery ${riderMoney(amount)}, ${confirmed ? 'confirmed' : 'awaiting confirmation'}',
      child: CustomPaint(
        foregroundPainter: _DashedRoundedBorderPainter(color: color),
        child: Material(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: confirmed ? null : onConfirm,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CASH ON DELIVERY',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          confirmed ? 'Confirmed' : 'Awaiting confirmation',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    riderMoney(amount),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 8, metric.length)),
          paint,
        );
        distance += 13;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _DeliveryActionPanel extends StatelessWidget {
  const _DeliveryActionPanel({
    required this.payout,
    required this.buttonLabel,
    required this.onPressed,
  });

  final double payout;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Your payout for this delivery',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                riderMoney(payout),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: palette.ratingStar),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RiderGradientButton(
            label: buttonLabel,
            icon: Icons.arrow_forward_rounded,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class DeliveryCompleteScreen extends StatefulWidget {
  const DeliveryCompleteScreen({super.key, this.delivery});

  final RiderDelivery? delivery;

  @override
  State<DeliveryCompleteScreen> createState() => _DeliveryCompleteScreenState();
}

class _DeliveryCompleteScreenState extends State<DeliveryCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.duration = const Duration(milliseconds: 100);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _continueOnline() async {
    final controller = RiderDependencyScope.of(context).controller;
    if (!(controller.profile?.isOnline ?? false)) {
      final succeeded = await controller.setOnline(true);
      if (!mounted || !succeeded) return;
    }
    RiderRouteScope.of(context)
      ..finishDelivery()
      ..sync(controller);
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(RiderRoutes.searching, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;
    final palette = riderPaletteOf(context);
    final riderName =
        RiderDependencyScope.of(context).controller.user?.name ?? 'Rider';
    final pop = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: .3, end: 1.12), weight: 72),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 28),
    ]).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    return Scaffold(
      body: Column(
        children: [
          RiderDuskHero(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
                child: Center(
                  child: Text(
                    'Delivery complete',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: pop,
                    child: Container(
                      width: 102,
                      height: 102,
                      decoration: BoxDecoration(
                        color: palette.success.withValues(alpha: .13),
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.success, width: 2),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: palette.success,
                        size: 54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nice work, ${riderName.split(' ').first}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${delivery?.displayNumber ?? 'Delivery'} · ${delivery?.deliveryAddress ?? 'Drop-off complete'}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 26),
                  _CompletionEarningsCard(delivery: delivery),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: RiderGradientButton(
                label: 'Continue online',
                icon: Icons.radar_rounded,
                onPressed: _continueOnline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionEarningsCard extends StatelessWidget {
  const _CompletionEarningsCard({required this.delivery});

  final RiderDelivery? delivery;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    final payout = delivery?.riderCommission ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          _EarningsLine(label: 'Delivery commission', amount: payout),
          if (delivery?.order?.paymentMethod.toUpperCase() == 'COD') ...[
            const SizedBox(height: 10),
            _EarningsLine(
              label: 'Cash collected for order',
              amount: delivery?.order?.total ?? 0,
              muted: true,
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: palette.line),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Total earned',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                riderMoney(payout),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: palette.ratingStar),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningsLine extends StatelessWidget {
  const _EarningsLine({
    required this.label,
    required this.amount,
    this.muted = false,
  });

  final String label;
  final double amount;
  final bool muted;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: muted
              ? Theme.of(context).textTheme.bodySmall
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      Text(riderMoney(amount), style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
