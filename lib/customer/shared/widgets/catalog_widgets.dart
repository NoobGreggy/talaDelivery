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
  Widget build(BuildContext context) {
    final fallback = StoreArtwork(
      icon: widget.product.icon,
      color: widget.product.color,
      large: widget.large,
      height: widget.height,
      width: widget.width,
    );
    if (bytes == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.large ? 0 : 17),
      child: Image.memory(
        bytes!,
        key: ValueKey('product-image-${widget.product.id}'),
        width: widget.width,
        height: widget.height ?? (widget.large ? 220 : 92),
        fit: BoxFit.cover,
        semanticLabel: widget.product.name,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
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
                          : '${store.openingTime} – ${store.closingTime ?? ''}',
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
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Hero(
                tag: product.name,
                child: SizedBox(
                  width: 76,
                  child: ProductArtwork(product: product, height: 76),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.description ?? 'No description provided.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.quiet, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      peso(product.price),
                      style: const TextStyle(
                        color: sky,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 42),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: onAdd == null
                    ? const Icon(Icons.block_rounded, size: 18)
                    : const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
