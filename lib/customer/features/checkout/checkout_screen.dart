part of '../../app.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.subtotal});
  final int subtotal;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar('Checkout'),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const CheckoutTitle(
                icon: Icons.location_on_outlined,
                title: 'Delivery address',
              ),
              const SizedBox(height: 10),
              InfoCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Juan Dela Cruz',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '123 Example Street\nCabanatuan City',
                            style: TextStyle(color: quiet),
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: null, child: Text('Change')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const CheckoutTitle(icon: Icons.phone_outlined, title: 'Contact'),
              const SizedBox(height: 10),
              const InfoCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recipient',
                            style: TextStyle(color: quiet, fontSize: 11),
                          ),
                          Text(
                            'Juan Dela Cruz',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone',
                            style: TextStyle(color: quiet, fontSize: 11),
                          ),
                          Text(
                            '0917 123 4567',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const CheckoutTitle(
                icon: Icons.sticky_note_2_outlined,
                title: 'Delivery notes',
              ),
              const SizedBox(height: 10),
              const TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Please call when outside.',
                ),
              ),
              const SizedBox(height: 20),
              const CheckoutTitle(
                icon: Icons.payments_outlined,
                title: 'Payment',
              ),
              const SizedBox(height: 10),
              const InfoCard(
                child: Row(
                  children: [
                    Icon(Icons.radio_button_checked_rounded, color: sky),
                    Icon(Icons.payments_rounded, color: success),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Pay ₱299 when your order arrives',
                            style: TextStyle(color: quiet, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const CheckoutTitle(
                icon: Icons.receipt_long_outlined,
                title: 'Summary',
              ),
              const SizedBox(height: 10),
              PriceSummary(subtotal: subtotal, delivery: 49),
            ],
          ),
        ),
        BottomAction(
          label: 'Place order • ₱${subtotal + 49}',
          onTap: () async {
            final confirmed = await confirmAction(
              context,
              title: 'Place this order?',
              body:
                  'ABC Mini Mart • ₱${subtotal + 49}\nPayment: Cash on Delivery',
              confirmLabel: 'Place order',
            );
            if (context.mounted && confirmed) {
              Navigator.pushNamed(
                context,
                CustomerRoutes.orderSuccess,
                arguments: subtotal + 49,
              );
              message(
                context,
                'Order placed successfully.',
                kind: ToastKind.success,
              );
            }
          },
        ),
      ],
    ),
  );
}
