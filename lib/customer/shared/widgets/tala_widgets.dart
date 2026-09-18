part of '../../app.dart';

/// The Tala primary action button.
///
/// Rounded, bold, with a restrained one-shot sheen on entrance and a native
/// press scale. When [loading] is true the label is replaced with a spinner.
class TalaButton extends StatefulWidget {
  const TalaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final IconData? icon;

  @override
  State<TalaButton> createState() => _TalaButtonState();
}

class _TalaButtonState extends State<TalaButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled && !widget.loading;
    return GestureDetector(
      onTapDown: canTap ? (_) => setState(() => pressed = true) : null,
      onTapCancel: canTap ? () => setState(() => pressed = false) : null,
      onTapUp: canTap
          ? (_) {
              setState(() => pressed = false);
              widget.onPressed?.call();
            }
          : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: pressed ? .985 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: canTap ? 1 : .72,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tint(sky, .12), sky, shade(sky, .1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: sky.withValues(alpha: .32),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  if (value <= 0 || value >= 1) return const SizedBox.shrink();
                  final width = MediaQuery.sizeOf(context).width - 60;
                  return Positioned(
                    left: -80 + value * (width + 160),
                    top: 6,
                    bottom: 6,
                    width: 46,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x33FFFFFF),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(
                height: 58,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.loading) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 9),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (!widget.loading && widget.icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(widget.icon, color: Colors.white, size: 17),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded [TextFormField] matching the Tala login sheet.
///
/// Keeps standard [TextFormField] behavior (validators, controllers, error
/// text) intact while moving focus styling and the floating label to the
/// approved visual direction.
class TalaPrimaryField extends StatefulWidget {
  const TalaPrimaryField({
    super.key,
    required this.label,
    required this.controller,
    this.prefixIcon,
    this.obscureText = false,
    this.onToggleVisibility,
    this.validator,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<TalaPrimaryField> createState() => _TalaPrimaryFieldState();
}

class _TalaPrimaryFieldState extends State<TalaPrimaryField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'tala-field-${widget.label}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;
    final baseBorder = Border.all(
      color: hasError ? danger : palette.line,
      width: 1,
    );
    final activeBorder = Border.all(color: sky, width: 1.4);
    final shadow = focused
        ? [
            BoxShadow(
              color: sky.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: .05),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ];

    return AnimatedBuilder(
      animation: _focusNode,
      builder: (context, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: focused || hasError ? activeBorder : baseBorder,
            boxShadow: shadow,
          ),
          child: TextFormField(
            key: widget.key,
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            autofocus: widget.autofocus,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              floatingLabelStyle: TextStyle(
                color: sky,
                fontWeight: FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
              labelStyle: TextStyle(
                color: palette.quiet,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              errorText: widget.errorText,
              contentPadding: const EdgeInsets.fromLTRB(16, 20, 14, 10),
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(
                      widget.prefixIcon,
                      size: 19,
                      color: focused ? sky : palette.quiet,
                    ),
              suffixIcon:
                  widget.obscureText && widget.onToggleVisibility != null
                  ? IconButton(
                      onPressed: widget.onToggleVisibility,
                      tooltip: widget.obscureText ? 'Show password' : 'Hide',
                      icon: Icon(
                        widget.obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: palette.quiet,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: palette.surface,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
        );
      },
    );
  }
}

/// Rounded marketplace search field. Submission is delegated to the caller so
/// the application's existing search implementation stays in charge.
class TalaSearchField extends StatefulWidget {
  const TalaSearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.hint = 'Search markets or essentials',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String hint;

  @override
  State<TalaSearchField> createState() => _TalaSearchFieldState();
}

class _TalaSearchFieldState extends State<TalaSearchField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return AnimatedBuilder(
      animation: _focusNode,
      builder: (context, _) {
        final focused = _focusNode.hasFocus;
        final hasText = widget.controller.text.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 58,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: focused ? tint(sky, .35) : palette.cardBorder,
              width: focused ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A)
                    .withValues(alpha: focused ? .06 : .04),
                blurRadius: focused ? 22 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Search stores',
                onPressed: () => widget.onSubmitted(widget.controller.text),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: focused ? sky : palette.quiet,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: widget.onSubmitted,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(color: palette.quiet, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: _clear,
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: palette.softBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: sky,
                    ),
                  ),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
        );
      },
    );
  }
}

/// Compact category chip used on the marketplace dashboard.
class TalaCategoryChip extends StatelessWidget {
  const TalaCategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final selectedFill = Theme.of(context).brightness == Brightness.dark
        ? shade(sky, .22)
        : palette.brand;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? selectedFill : palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? selectedFill : palette.cardBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: selectedFill.withValues(alpha: .16),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: .14)
                      : color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : palette.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: .6)
                        : palette.quiet,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tala market card using real store data only.
class TalaMarketCard extends StatelessWidget {
  const TalaMarketCard({super.key, required this.store, required this.onTap});

  final StoreData store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final categoryName = store.categories.isEmpty
        ? null
        : store.categories.first.name;
    final subtitle = store.categories.isEmpty
        ? (store.description ?? 'Market')
        : store.categories.take(3).map((c) => c.name).join(' · ');
    final hours = store.openingTime == null
        ? null
        : '${store.openingTime} – ${store.closingTime ?? ''}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: .06),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => IntrinsicHeight(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 152),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth * .34).clamp(88.0, 132.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tint(sky, .88), tint(sky, .78)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            bottomLeft: Radius.circular(28),
                          ),
                        ),
                        child: CustomPaint(
                          painter: _TalaOrbitPainter(
                            accent: sky.withValues(alpha: .28),
                            glow: Colors.white.withValues(alpha: .55),
                          ),
                          child: Center(
                            child: Icon(
                              store.icon,
                              size: 46,
                              color: sky.withValues(alpha: .85),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    store.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                StatusPill(
                                  label: store.open ? 'Open' : 'Closed',
                                  color: store.open ? success : danger,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.quiet,
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  color: palette.quiet,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    hours ?? 'Hours not provided',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.quiet,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (categoryName != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tint(sky, .88),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    categoryName.toUpperCase(),
                                    style: TextStyle(
                                      color: sky,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TalaOrbitPainter extends CustomPainter {
  const _TalaOrbitPainter({required this.accent, required this.glow});

  final Color accent;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .62;
    for (var i = 0; i < 2; i++) {
      final paint = Paint()
        ..color = i == 0 ? accent : glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 2 : 1
        ..strokeCap = StrokeCap.round;
      final rect = Rect.fromCircle(
        center: Offset(center.dx - 14 + i * 20, center.dy - 10 + i * 8),
        radius: radius - i * 14,
      );
      canvas.drawArc(
        rect,
        (i == 0 ? -0.6 : 1.1) * 3.14159,
        0.9 * 3.14159,
        false,
        paint,
      );
    }
    final dotPaint = Paint()..color = glow;
    canvas.drawCircle(Offset(center.dx - 22, center.dy - 20), 3, dotPaint);
    canvas.drawCircle(Offset(center.dx + 24, center.dy + 12), 2.4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _TalaOrbitPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.glow != glow;
}

/// Full-screen login success reveal.
///
/// Expands a Tala-blue circle from the sign-in button upward, then draws the
/// success check. Call [trigger] only AFTER real authentication succeeds; the
/// widget stays inert otherwise so the form always remains usable.
class TalaLoginSuccessReveal extends StatefulWidget {
  const TalaLoginSuccessReveal({
    super.key,
    required this.trigger,
    required this.onComplete,
  });

  final bool trigger;
  final VoidCallback onComplete;

  @override
  State<TalaLoginSuccessReveal> createState() => _TalaLoginSuccessRevealState();
}

class _TalaLoginSuccessRevealState extends State<TalaLoginSuccessReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _clip;
  late final Animation<double> _ringIn;
  late final Animation<double> _checkDraw;
  late final Animation<double> _contentIn;
  bool _launched = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _clip = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.72, curve: Curves.easeInOutCubic),
    );
    _ringIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.72, curve: Curves.easeOutBack),
    );
    _checkDraw = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.88, curve: Curves.easeOutCubic),
    );
    _contentIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_done) {
        _done = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void didUpdateWidget(TalaLoginSuccessReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !_launched) {
      _launched = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _TalaRevealPainter(progress: _clip.value, accent: sky),
            child: Opacity(
              opacity: _controller.value > 0 ? 1 : 0,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - _contentIn.value)),
                  child: Opacity(
                    opacity: _contentIn.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.82 + 0.18 * _ringIn.value,
                          child: Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .38),
                              ),
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(40, 40),
                                painter: _TalaCheckPainter(
                                  progress: _checkDraw.value,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Signing you in',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .75),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Signed in successfully',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Opening Tala Delivery…',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TalaRevealPainter extends CustomPainter {
  const _TalaRevealPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.78);
    final maxRadius = size.height * 1.6;
    final radius = progress * maxRadius;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [tint(accent, .15), accent, shade(accent, .18)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawCircle(center, radius, paint);
    if (progress < 1) {
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(center, radius - 2, ringPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TalaRevealPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _TalaCheckPainter extends CustomPainter {
  const _TalaCheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(10, 21.4)
      ..lineTo(17, 28.4)
      ..lineTo(30.4, 12.4);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final total = metrics.first.length;
    final draw = metrics.first.extractPath(0, total * progress);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    canvas.drawPath(draw, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TalaCheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
