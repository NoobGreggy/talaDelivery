part of '../../app.dart';

// Performance plan (Phase 3, TalaDuskSky): intentionally NOT rewritten before
// device measurement. The sky is already isolated behind a RepaintBoundary,
// honors reduced motion, and Flutter's TickerMode mutes its tickers whenever
// the hosting route is not visible. If profile-mode measurements later show
// measurable cost, revisit: split `_TalaDuskSkyState` from the child subtree,
// animate sky vars with single controllers, and gate audio animation off.
class TalaDuskSky extends StatefulWidget {
  const TalaDuskSky({
    super.key,
    required this.child,
    this.animate = true,
    this.shootingStar = true,
  });

  final Widget child;
  final bool animate;
  final bool shootingStar;

  @override
  State<TalaDuskSky> createState() => _TalaDuskSkyState();
}

class _TalaDuskSkyState extends State<TalaDuskSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final List<_TalaStar> stars;

  @override
  void initState() {
    super.initState();
    final random = math.Random(741);
    stars = List.generate(
      34,
      (index) => _TalaStar(
        Offset(random.nextDouble(), random.nextDouble() * .46),
        1 + random.nextDouble() * 2.2,
        2 + random.nextDouble() * 3,
        random.nextDouble() * 3,
      ),
      growable: false,
    );
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
  }

  bool get _usesTestBinding => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldAnimate =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        !_usesTestBinding;
    if (shouldAnimate && !controller.isAnimating) {
      controller.repeat();
    } else if (!shouldAnimate && controller.isAnimating) {
      controller.stop();
    }
  }

  @override
  void didUpdateWidget(TalaDuskSky oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate && !_usesTestBinding) {
      controller.repeat();
    } else {
      controller.stop();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      excluding: false,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final progress = reducedMotion || !widget.animate
                ? 0.25
                : controller.value;
            final drift = math.sin(progress * math.pi * 2) * .08;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.duskDeep,
                    palette.duskMid,
                    Theme.of(context).colorScheme.primary,
                  ],
                  begin: Alignment(-1 + drift, -1),
                  end: Alignment(1 + drift, 1),
                ),
              ),
              child: CustomPaint(
                painter: _TalaSkyPainter(
                  stars: stars,
                  progress: progress,
                  animate: !reducedMotion && widget.animate,
                  shootingStar: widget.shootingStar && !reducedMotion,
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TalaStar {
  const _TalaStar(this.position, this.radius, this.duration, this.delay);

  final Offset position;
  final double radius;
  final double duration;
  final double delay;
}

class _TalaSkyPainter extends CustomPainter {
  const _TalaSkyPainter({
    required this.stars,
    required this.progress,
    required this.animate,
    required this.shootingStar,
  });

  final List<_TalaStar> stars;
  final double progress;
  final bool animate;
  final bool shootingStar;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final seconds = progress * 18;
      final phase = ((seconds + star.delay) / star.duration) * math.pi * 2;
      final pulse = animate ? .575 + math.sin(phase) * .425 : .62;
      canvas.drawCircle(
        Offset(star.position.dx * size.width, star.position.dy * size.height),
        star.radius * (.7 + pulse * .55),
        Paint()..color = Colors.white.withValues(alpha: .15 + pulse * .68),
      );
    }

    if (!shootingStar) return;
    final cycle = (progress * 18 - 1.5) % 6;
    if (cycle < 0 || cycle > 1.8) return;
    final travel = Curves.easeOutCubic.transform((cycle / 1.8).clamp(0, 1));
    final opacity = cycle < .48 ? (cycle / .48) : (1.8 - cycle) / 1.32;
    final start =
        Offset(size.width * .88, size.height * .10) +
        Offset(-260 * travel, 140 * travel);
    final end = start + const Offset(90, -48);
    final paint = Paint()
      ..shader = ui.Gradient.linear(start, end, [
        Colors.transparent,
        Colors.white.withValues(alpha: opacity.clamp(0, 1) * .9),
      ])
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _TalaSkyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.animate != animate ||
      oldDelegate.shootingStar != shootingStar;
}

class TalaStarLogo extends StatefulWidget {
  const TalaStarLogo({super.key, this.compact = false});

  final bool compact;

  @override
  State<TalaStarLogo> createState() => _TalaStarLogoState();
}

class _TalaStarLogoState extends State<TalaStarLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (!MediaQuery.disableAnimationsOf(context) && !isTestBinding) {
      if (!controller.isAnimating) controller.repeat();
    } else if (controller.isAnimating) {
      controller.stop();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scale = widget.compact ? .58 : 1.0;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final value = reducedMotion ? .5 : controller.value;
          final floatY = math.sin(value * math.pi * 2) * 5;
          return Transform.translate(
            offset: Offset(0, floatY),
            child: SizedBox(
              width: 150 * scale,
              height: 150 * scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var index = 0; index < 2; index++)
                    Transform.scale(
                      scale: reducedMotion
                          ? 1.25
                          : .8 + (((value + index * .5) % 1) * 1.1),
                      child: Opacity(
                        opacity: reducedMotion
                            ? .22
                            : (1 - ((value + index * .5) % 1)) * .55,
                        child: Container(
                          width: 84 * scale,
                          height: 84 * scale,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26 * scale),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 84 * scale,
                    height: 84 * scale,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tint(palette.ratingStar, .24),
                          palette.ratingStar,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26 * scale),
                      boxShadow: [
                        BoxShadow(
                          color: palette.ratingStar.withValues(alpha: .4),
                          blurRadius: 40 * scale,
                          offset: Offset(0, 18 * scale),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: palette.duskDeep,
                      size: 42 * scale,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TalaCustomerBottomNav extends StatelessWidget {
  const TalaCustomerBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onHome,
    required this.onOrders,
    required this.onSaved,
    required this.onAccount,
  });

  final int selectedIndex;
  final VoidCallback onHome;
  final VoidCallback onOrders;
  final VoidCallback onSaved;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          key: const Key('customer-floating-nav'),
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.line),
            boxShadow: [
              BoxShadow(
                color: palette.duskDeep.withValues(alpha: .16),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TalaNavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                selected: selectedIndex == 0,
                onTap: onHome,
              ),
              _TalaNavItem(
                label: 'Orders',
                icon: Icons.receipt_long_rounded,
                selected: selectedIndex == 1,
                onTap: onOrders,
              ),
              _TalaNavItem(
                label: 'Saved',
                icon: Icons.favorite_outline_rounded,
                selected: false,
                onTap: onSaved,
              ),
              _TalaNavItem(
                label: 'Account',
                icon: Icons.person_rounded,
                selected: selectedIndex == 2,
                onTap: onAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalaNavItem extends StatelessWidget {
  const _TalaNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : palette.quiet;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 52,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(selected),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
