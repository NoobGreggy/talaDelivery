part of '../../app.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CustomerDependencyScope.of(context).cartController;
    return Scaffold(
      appBar: simpleBar('Your cart'),
      body: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (cart.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              subtitle: 'Choose an available product from a store.',
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    InfoCard(
                      child: Row(
                        children: [
                          StoreArtwork(
                            icon: cart.store!.icon,
                            color: cart.store!.color,
                            height: 54,
                            width: 54,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cart.store!.name,
                                  style: TextStyle(
                                    color: appPaletteOf(context).text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'One store per order',
                                  style: TextStyle(
                                    color: appPaletteOf(context).quiet,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Add items'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...cart.lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CartItem(
                          name: line.product.name,
                          price: line.product.price,
                          quantity: line.quantity,
                          icon: line.product.icon,
                          onMinus: () => cart.setQuantity(
                            line.product.id,
                            line.quantity - 1,
                          ),
                          onPlus: line.quantity < line.product.stock
                              ? () => cart.setQuantity(
                                  line.product.id,
                                  line.quantity + 1,
                                )
                              : () {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PriceSummary(subtotal: cart.subtotal),
                    const SizedBox(height: 15),
                    const InfoBanner(
                      icon: Icons.info_outline_rounded,
                      text: 'Laravel validates current stock, prices, and the delivery fee when you place the order.',
                    ),
                  ],
                ),
              ),
              BottomAction(
                label: 'Continue to checkout • ${peso(cart.subtotal)}',
                onTap: () =>
                    Navigator.pushNamed(context, CustomerRoutes.checkout),
              ),
            ],
          );
        },
      ),
    );
  }
}
