part of '../../app.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  int rice = 2;
  int drink = 1;
  int get subtotal => rice * 100 + drink * 50;

  void updateQuantity(String item, bool increase) {
    setState(() {
      if (item == 'rice') {
        rice = increase ? rice + 1 : (rice > 1 ? rice - 1 : 1);
      } else {
        drink = increase ? drink + 1 : (drink > 1 ? drink - 1 : 1);
      }
    });
    message(context, 'Cart quantity updated.', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar('Your cart'),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InfoCard(
                child: Row(
                  children: [
                    const StoreArtwork(
                      icon: Icons.storefront_rounded,
                      color: sky,
                      height: 54,
                      width: 54,
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ABC Mini Mart',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Items from one store only',
                            style: TextStyle(color: quiet, fontSize: 12),
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
              CartItem(
                name: 'Chicken Rice Bowl',
                price: 100,
                quantity: rice,
                icon: Icons.rice_bowl_rounded,
                onMinus: () => updateQuantity('rice', false),
                onPlus: () => updateQuantity('rice', true),
              ),
              const SizedBox(height: 10),
              CartItem(
                name: 'Iced Tea',
                price: 50,
                quantity: drink,
                icon: Icons.local_drink_rounded,
                onMinus: () => updateQuantity('drink', false),
                onPlus: () => updateQuantity('drink', true),
              ),
              const SizedBox(height: 18),
              PriceSummary(subtotal: subtotal, delivery: 49),
              const SizedBox(height: 15),
              const InfoBanner(
                icon: Icons.info_outline_rounded,
                text: 'Product availability and prices will be validated at checkout.',
              ),
            ],
          ),
        ),
        BottomAction(
          label: 'Checkout • ₱${subtotal + 49}',
          onTap: () => Navigator.pushNamed(
            context,
            CustomerRoutes.checkout,
            arguments: subtotal,
          ),
        ),
      ],
    ),
  );
}
