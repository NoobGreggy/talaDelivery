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
    final palette = appPaletteOf(context);
    final scheme = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
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
        scale: pressed ? .97 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: canTap ? 1 : .45,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, palette.duskMid],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: canTap
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: .34),
                              blurRadius: 26,
                              offset: const Offset(0, 14),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 3200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  if (!canTap || reducedMotion || value <= 0 || value >= 1) {
                    return const SizedBox.shrink();
                  }
                  final width = MediaQuery.sizeOf(context).width - 60;
                  return Positioned(
                    left: -80 + value * (width + 160),
                    top: 6,
                    bottom: 6,
                    width: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: .35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(
                height: 54,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      else
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
    this.autofillHints,
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
  final Iterable<String>? autofillHints;

  @override
  State<TalaPrimaryField> createState() => _TalaPrimaryFieldState();
}

class _TalaPrimaryFieldState extends State<TalaPrimaryField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'tala-field-${widget.label}');
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final scheme = Theme.of(context).colorScheme;
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;
    final baseBorder = Border.all(
      color: hasError ? scheme.error : palette.line,
      width: 1.5,
    );
    final activeBorder = Border.all(
      color: hasError ? scheme.error : scheme.primary,
      width: 1.5,
    );
    final shadow = focused
        ? [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .16),
              blurRadius: 0,
              spreadRadius: 4,
            ),
          ]
        : null;

    final borderRadius = BorderRadius.circular(14);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: focused || hasError ? activeBorder : baseBorder,
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: TextFormField(
          key: widget.key,
          controller: widget.controller,
          focusNode: _focusNode,
          contextMenuBuilder: (context, editableTextState) =>
              AdaptiveTextSelectionToolbar.editableText(
                editableTextState: editableTextState,
              ),
          obscureText: widget.obscureText,
          autofillHints: widget.autofillHints,
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
              color: scheme.primary,
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
            contentPadding: const EdgeInsets.fromLTRB(14, 17, 14, 11),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(
                    widget.prefixIcon,
                    size: 19,
                    color: focused ? scheme.primary : palette.quiet,
                  ),
            suffixIcon: widget.onToggleVisibility != null
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
            fillColor: focused ? palette.surface : palette.background,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
        ),
      ),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? ', selected' : ''}',
      child: InkResponse(
        onTap: onTap,
        radius: 42,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    color.withValues(alpha: .18),
                    palette.surface,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: .4)),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: .3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? palette.text : palette.quiet,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected ? primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tala market card using real store data only.
class TalaMarketCard extends StatefulWidget {
  const TalaMarketCard({super.key, required this.store, required this.onTap});

  final StoreData store;
  final VoidCallback onTap;

  @override
  State<TalaMarketCard> createState() => _TalaMarketCardState();
}

class _TalaMarketCardState extends State<TalaMarketCard> {
  bool saved = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final store = widget.store;
    final categoryName = store.categories.isEmpty
        ? null
        : store.categories.first.name;
    final subtitle = store.categories.isEmpty
        ? (store.description ?? 'Market')
        : store.categories.take(3).map((c) => c.name).join(' · ');
    final hours = store.openingTime == null
        ? null
        : '${_talaShortHour(store.openingTime!)} – ${_talaShortHour(store.closingTime ?? '')}';
    final imageUrl = store.products
        .map((product) => product.image)
        .whereType<String>()
        .firstOrNull;

    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: pressed ? .98 : 1,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => pressed = value),
          child: Ink(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.line),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow
                      .withValues(alpha: .06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _StoreImageFallback(icon: store.icon),
                      if (imageUrl != null)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final dpr = MediaQuery.devicePixelRatioOf(context);
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: (constraints.maxWidth * dpr).ceil(),
                              cacheHeight: (constraints.maxHeight * dpr).ceil(),
                              gaplessPlayback: true,
                              frameBuilder: (
                                context,
                                child,
                                frame,
                                wasSynchronouslyLoaded,
                              ) {
                                if (wasSynchronouslyLoaded) return child;
                                if (frame == null) return const SizedBox.shrink();
                                return child;
                              },
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            );
                          },
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: .35),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Semantics(
                          button: true,
                          label: saved
                              ? 'Remove ${store.name} from saved'
                              : 'Save ${store.name}',
                          child: InkWell(
                            onTap: () => setState(() => saved = !saved),
                            borderRadius: BorderRadius.circular(11),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .85),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                saved
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: palette.urgent,
                                size: 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
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
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (store.open ? palette.positive : palette.line)
                                      .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              store.open ? 'Open' : 'Closed',
                              style: TextStyle(
                                color: store.open
                                    ? palette.positive
                                    : palette.quiet,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.quiet, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: palette.line),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: palette.quiet,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hours ?? 'Hours not provided',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.quiet,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (categoryName != null)
                            Text(
                              categoryName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
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

class _StoreImageFallback extends StatelessWidget {
  const _StoreImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.duskDeep, Theme.of(context).colorScheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withValues(alpha: .88), size: 44),
      ),
    );
  }
}

// ignore: unused_element
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
