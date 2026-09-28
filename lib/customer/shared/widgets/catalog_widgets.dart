part of '../../app.dart';

class CategoryButton extends StatefulWidget {
  const CategoryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  State<CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<CategoryButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => pressed = true),
    onTapCancel: () => setState(() => pressed = false),
    onTapUp: (_) {
      setState(() => pressed = false);
      widget.onTap();
    },
    child: AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: pressed ? .94 : 1,
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Center(
              child: Icon(widget.icon, color: widget.color, size: 27),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: appPaletteOf(context).text,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class StoreArtwork extends StatelessWidget {
  const StoreArtwork({
    super.key,
    required this.icon,
    required this.color,
    this.large = false,
    this.height,
    this.width,
  });
  final IconData icon;
  final Color color;
  final bool large;
  final double? height;
  final double? width;
  @override
  Widget build(BuildContext context) => Container(
    height: height ?? (large ? 220 : 92),
    width: width,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(large ? 0 : 17),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: color, size: large ? 82 : 38),
        if (large) ...[
          Positioned(
            right: 24,
            top: 28,
            child: Icon(
              Icons.auto_awesome,
              color: color.withValues(alpha: .45),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 32,
            child: Icon(
              Icons.circle,
              color: color.withValues(alpha: .18),
              size: 40,
            ),
          ),
        ],
      ],
    ),
  );
}

Uint8List? _productImageBytes(String? dataUri) {
  if (dataUri == null || dataUri.length > 7 * 1024 * 1024 + 100) return null;
  final comma = dataUri.indexOf(',');
  if (comma < 0 ||
      !RegExp(
        r'^data:image/(png|jpe?g|gif|webp);base64$',
        caseSensitive: false,
      ).hasMatch(dataUri.substring(0, comma))) {
    return null;
  }
  try {
    final bytes = base64Decode(dataUri.substring(comma + 1));
    return bytes.length <= 5 * 1024 * 1024 ? bytes : null;
  } on FormatException {
    return null;
  }
}

class ProductArtwork extends StatefulWidget {
  const ProductArtwork({
    super.key,
    required this.product,
    this.large = false,
    this.height,
    this.width,
  });

  final ProductData product;
  final bool large;
  final double? height;
  final double? width;

  @override
  State<ProductArtwork> createState() => _ProductArtworkState();
}

class _ProductArtworkState extends State<ProductArtwork> {
  Uint8List? bytes;

  @override
  void initState() {
    super.initState();
    bytes = _productImageBytes(widget.product.image);
  }

  @override
  void didUpdateWidget(ProductArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.image != widget.product.image) {
      bytes = _productImageBytes(widget.product.image);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Resolve the box from the parent constraints so a food picture always
      // fills the space reserved for it instead of shrink-wrapping its own
      // aspect ratio.
      final width =
          widget.width ??
          (constraints.hasBoundedWidth ? constraints.maxWidth : null);
      final height =
          widget.height ??
          (constraints.hasBoundedHeight
              ? constraints.maxHeight
              : (widget.large ? 220 : 92));
      final fallback = StoreArtwork(
        icon: widget.product.icon,
        color: widget.product.color,
        large: widget.large,
        height: height,
        width: width ?? double.infinity,
      );
      if (bytes == null) return fallback;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheWidth = width == null ? null : (width * dpr).ceil();
      final cacheHeight = (height * dpr).ceil();
      final picture = Image.memory(
        bytes!,
        key: ValueKey('product-image-${widget.product.id}'),
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fit: BoxFit.cover,
        semanticLabel: widget.product.name,
        errorBuilder: (_, _, _) => fallback,
      );
      if (widget.large) return picture;
      return ClipRRect(borderRadius: BorderRadius.circular(17), child: picture);
    },
  );
}

class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store, required this.onTap});
  final StoreData store;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: StoreArtwork(icon: store.icon, color: store.color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: TextStyle(
                              color: palette.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: store.open ? 'Open' : 'Closed',
                          color: store.open ? success : danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      store.address ?? store.description ?? 'Store details',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.quiet, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Metric(
                      icon: Icons.schedule_rounded,
                      value: store.openingTime == null
                          ? 'Hours not provided'
                          : '${_talaShortHour(store.openingTime!)} – ${_talaShortHour(store.closingTime ?? '')}',
                      color: palette.quiet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: appPaletteOf(context).quiet,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.product,
    required this.onOpen,
    this.onAdd,
  });
  final ProductData product;
  final VoidCallback onOpen;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final primary = Theme.of(context).colorScheme.primary;
    final canAdd = onAdd != null;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.line),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow
                    .withValues(alpha: .05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: product.name,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ProductArtwork(
                      product: product,
                      width: 96,
                      height: 112,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        product.description ?? 'No description provided.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.quiet,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 7),
                      if (product.available)
                        Text(
                          '${product.stock} available',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.quiet,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: StatusPill(label: 'SOLD OUT', color: danger),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  peso(product.price),
                                  style: TextStyle(
                                    color: palette.text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: canAdd
                                ? 'Add ${product.name}'
                                : '${product.name} is unavailable',
                            child: Semantics(
                              button: true,
                              enabled: canAdd,
                              label: canAdd
                                  ? 'Add ${product.name}'
                                  : '${product.name} is unavailable',
                              child: FilledButton(
                                key: Key('product-add-${product.id}'),
                                onPressed: onAdd,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  maximumSize: const Size(48, 48),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  backgroundColor: canAdd
                                      ? primary
                                      : palette.line,
                                  foregroundColor: canAdd
                                      ? Colors.white
                                      : palette.quiet,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: Icon(
                                  canAdd
                                      ? Icons.add_rounded
                                      : Icons.block_rounded,
                                  size: 25,
                                ),
                              ),
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
