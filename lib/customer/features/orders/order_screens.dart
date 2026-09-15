part of '../../app.dart';

class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({super.key, required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: Color(0xFFE3F8EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: success, size: 60),
            ),
            const SizedBox(height: 25),
            Text(
              'Order placed!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your order has been sent to ABC Mini Mart.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            InfoCard(
              child: Column(
                children: [
                  const SummaryLine(label: 'Order', value: '#TD-100001'),
                  const SummaryLine(label: 'Store', value: 'ABC Mini Mart'),
                  SummaryLine(label: 'Total', value: '₱$total', bold: true),
                  const SummaryLine(
                    label: 'Payment',
                    value: 'Cash on Delivery',
                    last: true,
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryAction(
              label: 'Track order',
              icon: Icons.location_on_rounded,
              onTap: () => Navigator.pushReplacementNamed(
                context,
                CustomerRoutes.orderTracking,
                arguments: OrderStage.findingRider,
              ),
            ),
            const SizedBox(height: 9),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    ),
  );
}

enum OrderStage {
  placed,
  confirmed,
  preparing,
  findingRider,
  assigned,
  pickedUp,
  outForDelivery,
  delivered,
}

extension StageUi on OrderStage {
  String get title => switch (this) {
    OrderStage.placed => 'Order placed',
    OrderStage.confirmed => 'Store confirmed',
    OrderStage.preparing => 'Store is preparing',
    OrderStage.findingRider => 'Finding your rider…',
    OrderStage.assigned => 'Rider assigned',
    OrderStage.pickedUp => 'Order picked up',
    OrderStage.outForDelivery => 'Your order is on the way!',
    OrderStage.delivered => 'Delivered!',
  };
  String get description => switch (this) {
    OrderStage.placed => 'Waiting for the store to confirm your order.',
    OrderStage.confirmed => 'ABC Mini Mart has accepted your order.',
    OrderStage.preparing => 'The store is preparing your items.',
    OrderStage.findingRider =>
      'We’re looking for a nearby rider to deliver your order.',
    OrderStage.assigned => 'Juan is heading to the store.',
    OrderStage.pickedUp => 'Juan has picked up your order.',
    OrderStage.outForDelivery => 'Juan is delivering to 123 Example Street.',
    OrderStage.delivered => 'Thank you for ordering with TalaDelivery.',
  };
}

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({
    super.key,
    this.initialStage = OrderStage.findingRider,
  });
  final OrderStage initialStage;
  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late OrderStage stage;
  @override
  void initState() {
    super.initState();
    stage = widget.initialStage;
  }

  void next() {
    if (stage.index < OrderStage.values.length - 1) {
      final nextStage = OrderStage.values[stage.index + 1];
      setState(() => stage = nextStage);
      message(
        context,
        'Order updated: ${nextStage.title}.',
        kind: ToastKind.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRider =
        stage.index >= OrderStage.assigned.index &&
        stage != OrderStage.delivered;
    return Scaffold(
      appBar: simpleBar(
        'Order #TD-100001',
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, CustomerRoutes.notifications),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: TrackingHero(key: ValueKey(stage), stage: stage),
          ),
          const SizedBox(height: 14),
          if (hasRider) ...[
            RiderCard(stage: stage),
            const SizedBox(height: 14),
          ],
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    StoreArtwork(
                      icon: Icons.storefront_rounded,
                      color: sky,
                      height: 48,
                      width: 48,
                    ),
                    SizedBox(width: 12),
                    Expanded(
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
                            '₱299 • Cash on Delivery',
                            style: TextStyle(color: quiet, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...OrderStage.values.map(
                  (item) => TimelineItem(
                    label: item == OrderStage.findingRider
                        ? 'Finding rider'
                        : item.title,
                    complete: item.index < stage.index,
                    active: item == stage,
                    last: item == OrderStage.delivered,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const InfoBanner(
            icon: Icons.sync_rounded,
            text: 'This static preview represents automatic order updates in the connected app.',
          ),
          const SizedBox(height: 14),
          if (stage != OrderStage.delivered)
            PrimaryAction(
              label: 'Preview next update',
              icon: Icons.fast_forward_rounded,
              onTap: next,
            ),
          if (stage == OrderStage.placed) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => showCancelDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: danger,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: danger),
              ),
              child: const Text('Cancel order'),
            ),
          ],
          if (stage == OrderStage.delivered) ...[
            const SizedBox(height: 2),
            PrimaryAction(
              label: 'View order',
              onTap: () => message(context, 'Order receipt preview opened.'),
            ),
          ],
        ],
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        Text('My orders', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text('Track active orders and view your history.'),
        const SizedBox(height: 20),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Active')),
            ButtonSegment(value: 1, label: Text('Completed')),
            ButtonSegment(value: 2, label: Text('Cancelled')),
          ],
          selected: {tab},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => tab = value.first),
        ),
        const SizedBox(height: 20),
        if (tab == 0) ...[
          OrderHistoryCard(
            store: 'ABC Mini Mart',
            id: '#TD-100001',
            total: '₱299',
            status: 'FINDING RIDER',
            color: sky,
            date: 'September 13, 2026',
            onTap: () =>
                Navigator.pushNamed(context, CustomerRoutes.orderTracking),
          ),
          const SizedBox(height: 11),
          OrderHistoryCard(
            store: 'XYZ Food House',
            id: '#TD-100002',
            total: '₱249',
            status: 'PENDING',
            color: warning,
            date: 'September 13, 2026',
            onTap: () => Navigator.pushNamed(
              context,
              CustomerRoutes.orderTracking,
              arguments: OrderStage.placed,
            ),
          ),
        ] else if (tab == 1) ...[
          OrderHistoryCard(
            store: 'ABC Mini Mart',
            id: '#TD-099981',
            total: '₱315',
            status: 'DELIVERED',
            color: success,
            date: 'September 11, 2026',
            onTap: () => Navigator.pushNamed(
              context,
              CustomerRoutes.orderTracking,
              arguments: OrderStage.delivered,
            ),
          ),
          const SizedBox(height: 11),
          OrderHistoryCard(
            store: 'Mercury Pharmacy',
            id: '#TD-099944',
            total: '₱540',
            status: 'DELIVERED',
            color: success,
            date: 'September 8, 2026',
            onTap: () => Navigator.pushNamed(
              context,
              CustomerRoutes.orderTracking,
              arguments: OrderStage.delivered,
            ),
          ),
        ] else
          const EmptyState(
            icon: Icons.cancel_outlined,
            title: 'No cancelled orders',
            subtitle: 'Orders you cancel will appear here.',
          ),
      ],
    ),
  );
}
