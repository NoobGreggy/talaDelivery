part of '../../app.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onEarnings,
  });

  final RiderAppController controller;
  final VoidCallback onEarnings;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const _dailyGoal = 1000.0;
  late final AnimationController _rings;
  late final AnimationController _goal;
  double _goalFrom = 0;
  double _goalTo = 0;
  bool _pressed = false;
  bool _confirmingOnline = false;

  @override
  void initState() {
    super.initState();
    _rings = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _goal = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _setGoal(animate: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _rings.stop();
    } else if (!_rings.isAnimating) {
      _rings.repeat();
    }
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setGoal(animate: true);
  }

  void _setGoal({required bool animate}) {
    final next = (widget.controller.todayEarnings / _dailyGoal).clamp(0.0, 1.0);
    if (next == _goalTo) return;
    _goalFrom = _goal.value == 0
        ? _goalTo
        : _goalFrom + ((_goalTo - _goalFrom) * _goal.value);
    _goalTo = next;
    if (animate) {
      _goal.forward(from: 0);
    } else {
      _goal.value = 1;
    }
  }

  @override
  void dispose() {
    _rings.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _goOnline() async {
    final profile = widget.controller.profile;
    if (profile == null || !profile.canGoOnline || _confirmingOnline) return;
    final succeeded = await widget.controller.setOnline(true);
    if (!mounted) return;
    if (!succeeded) {
      showMessage(
        context,
        widget.controller.errorMessage ?? 'Availability could not be updated.',
        kind: RiderToastKind.warning,
      );
      return;
    }
    setState(() => _confirmingOnline = true);
    RiderRouteScope.of(context).setOnline(true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushNamed(RiderRoutes.searching);
    setState(() => _confirmingOnline = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final profile = controller.profile;
    if (controller.isLoading && profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile == null) {
      return RiderEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Rider data unavailable',
        message:
            controller.errorMessage ??
            'Pull your profile from the server again.',
        action: 'Retry',
        onAction: controller.refresh,
      );
    }
    final palette = riderPaletteOf(context);
    final completed = controller.completedDeliveries;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: controller.refresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _DashboardHero(
            controller: controller,
            profile: profile,
            confirmingOnline: _confirmingOnline,
            pressed: _pressed,
            rings: _rings,
            onPressedChanged: (value) => setState(() => _pressed = value),
            onPower: _goOnline,
          ),
          Transform.translate(
            offset: const Offset(0, -46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TodaySnapshot(
                earnings: controller.todayEarnings,
                deliveries: controller.todayDeliveries,
                rating: profile.rating,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _DailyGoalCard(
                    earnings: controller.todayEarnings,
                    goal: _dailyGoal,
                    animation: _goal,
                    from: _goalFrom,
                    to: _goalTo,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _GaugeCard(
                          label: 'Acceptance rate',
                          value: profile.acceptanceRate,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GaugeCard(
                          label: 'On-time rate',
                          value: profile.onTimeRate,
                          color: palette.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SectionTitle(
                    title: 'Recent deliveries',
                    action: 'View history',
                    onAction: widget.onEarnings,
                  ),
                  const SizedBox(height: 12),
                  if (completed.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.line),
                      ),
                      child: Text(
                        'Completed deliveries will appear here.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ...completed
                        .take(5)
                        .map(
                          (delivery) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DeliveryRow(delivery: delivery),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.controller,
    required this.profile,
    required this.confirmingOnline,
    required this.pressed,
    required this.rings,
    required this.onPressedChanged,
    required this.onPower,
  });

  final RiderAppController controller;
  final RiderProfile profile;
  final bool confirmingOnline;
  final bool pressed;
  final Animation<double> rings;
  final ValueChanged<bool> onPressedChanged;
  final VoidCallback onPower;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return RiderDuskHero(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 74),
          child: Column(
            children: [
              Row(
                children: [
                  const RiderLogo(size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: onPrimary.withValues(alpha: .7),
                              ),
                        ),
                        Text(
                          profile.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: onPrimary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('rider-wallet-shortcut'),
                    tooltip: 'Tala Coins wallet',
                    onPressed: () =>
                        Navigator.of(context).pushNamed(RiderRoutes.wallet),
                    icon: const RiderCoinImage(),
                  ),
                  Semantics(
                    button: true,
                    label:
                        'Notifications, ${controller.unreadNotificationCount} unread',
                    child: IconButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .pushNamed(RiderRoutes.notifications),
                      icon: Badge.count(
                        count: controller.unreadNotificationCount,
                        isLabelVisible: controller.unreadNotificationCount > 0,
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _RiderPowerButton(
                online: confirmingOnline,
                enabled: profile.canGoOnline && !controller.isSubmitting,
                pressed: pressed,
                rings: rings,
                onPressedChanged: onPressedChanged,
                onTap: onPower,
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? const Duration(milliseconds: 120)
                    : const Duration(milliseconds: 400),
                child: Text(
                  confirmingOnline ? 'You’re online' : 'You’re offline',
                  key: ValueKey(confirmingOnline),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: onPrimary, fontSize: 18),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                confirmingOnline
                    ? 'Searching for deliveries nearby…'
                    : profile.canGoOnline
                    ? 'Tap the power button to start receiving deliveries'
                    : 'Your account must be approved before going online',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: onPrimary.withValues(alpha: .74)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiderPowerButton extends StatelessWidget {
  const _RiderPowerButton({
    required this.online,
    required this.enabled,
    required this.pressed,
    required this.rings,
    required this.onPressedChanged,
    required this.onTap,
  });

  final bool online;
  final bool enabled;
  final bool pressed;
  final Animation<double> rings;
  final ValueChanged<bool> onPressedChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = riderPaletteOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: const Key('rider-power-button'),
      button: true,
      enabled: enabled,
      label: online ? 'Go offline, currently online' : 'Go online',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        onTapDown: enabled ? (_) => onPressedChanged(true) : null,
        onTapUp: enabled ? (_) => onPressedChanged(false) : null,
        onTapCancel: enabled ? () => onPressedChanged(false) : null,
        child: AnimatedScale(
          scale: pressed ? .96 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: SizedBox.square(
            dimension: 156,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (online)
                  AnimatedBuilder(
                    animation: rings,
                    builder: (context, _) => CustomPaint(
                      size: const Size.square(156),
                      painter: _PowerRingPainter(
                        progress: reduceMotion ? 0 : rings.value,
                        color: scheme.onPrimary,
                        animate: online && !reduceMotion,
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: reduceMotion
                      ? const Duration(milliseconds: 120)
                      : const Duration(milliseconds: 400),
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online
                        ? null
                        : scheme.onPrimary.withValues(alpha: .12),
                    gradient: online
                        ? RadialGradient(
                            colors: [
                              scheme.primary.withValues(alpha: .78),
                              scheme.primary,
                              palette.duskMid,
                            ],
                          )
                        : null,
                    border: Border.all(
                      color: scheme.onPrimary.withValues(
                        alpha: online ? .5 : .2,
                      ),
                      width: 2,
                    ),
                    boxShadow: online
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: .48),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    color: scheme.onPrimary.withValues(alpha: online ? 1 : .68),
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerRingPainter extends CustomPainter {
  const _PowerRingPainter({
    required this.progress,
    required this.color,
    required this.animate,
  });

  final double progress;
  final Color color;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (!animate) {
      canvas.drawCircle(
        center,
        70,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: .22),
      );
      return;
    }
    for (var index = 0; index < 2; index++) {
      final value = (progress + index * .5) % 1;
      final scale = .78 + (.44 * Curves.easeIn.transform(value));
      canvas.drawCircle(
        center,
        64 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: .6 * (1 - value)),
      );
    }
  }

  @override
  bool shouldRepaint(_PowerRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      animate != oldDelegate.animate;
}

class _TodaySnapshot extends StatelessWidget {
  const _TodaySnapshot({
    required this.earnings,
    required this.deliveries,
    required this.rating,
  });

  final double earnings;
  final int deliveries;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: .1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SnapshotValue(
              value: riderMoney(earnings),
              label: 'Today’s earnings',
            ),
          ),
          SizedBox(height: 38, child: VerticalDivider(color: palette.line)),
          Expanded(
            child: _SnapshotValue(value: '$deliveries', label: 'Deliveries'),
          ),
          SizedBox(height: 38, child: VerticalDivider(color: palette.line)),
          Expanded(
            child: _SnapshotValue(
              value: rating == null ? '—' : rating!.toStringAsFixed(1),
              label: 'Rating',
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotValue extends StatelessWidget {
  const _SnapshotValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({
    required this.earnings,
    required this.goal,
    required this.animation,
    required this.from,
    required this.to,
  });

  final double earnings;
  final double goal;
  final Animation<double> animation;
  final double from;
  final double to;

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
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily goal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${riderMoney(earnings)} of ${riderMoney(goal)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final value =
                  from +
                  ((to - from) *
                      Curves.easeOutCubic.transform(animation.value));
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: palette.line),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                palette.duskMid,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    final normalized = ((value ?? 0) / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 76,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: normalized,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: palette.line,
                ),
                Center(
                  child: Text(
                    value == null ? '—' : '${value!.round()}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
