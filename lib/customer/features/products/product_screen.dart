part of '../../app.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final ProductData product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar('Product details'),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Hero(
                tag: widget.product.name,
                child: StoreArtwork(
                  icon: widget.product.icon,
                  color: widget.product.color,
                  large: true,
                  height: 250,
                ),
              ),
              const SizedBox(height: 23),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (!widget.product.available)
                    const StatusPill(label: 'OUT OF STOCK', color: danger),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.product.description ?? 'No description provided.',
                style: TextStyle(
                  color: appPaletteOf(context).quiet,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                peso(widget.product.price),
                style: const TextStyle(
                  color: sky,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.product.stock} in stock',
                style: TextStyle(color: appPaletteOf(context).quiet),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Text(
                    'Quantity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  QuantityControl(
                    value: quantity,
                    onMinus: quantity > 1
                        ? () => setState(() => quantity--)
                        : null,
                    onPlus:
                        widget.product.available &&
                            quantity < widget.product.stock
                        ? () => setState(() => quantity++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        BottomAction(
          label: widget.product.available
              ? 'Add to cart • ${peso(widget.product.price * quantity)}'
              : 'Currently unavailable',
          enabled: widget.product.available,
          onTap: () => Navigator.pop(context, quantity),
        ),
      ],
    ),
  );
}
