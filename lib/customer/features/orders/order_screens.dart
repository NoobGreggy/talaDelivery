part of '../../app.dart';

class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({super.key, required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: appPaletteOf(context).successCircleFill,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: success,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        'Order placed!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your order was sent to ${order.store?.name ?? 'the store'}.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  InfoCard(
                    child: Column(
                      children: [
                        SummaryLine(label: 'Order', value: order.orderNumber),
                        SummaryLine(
                          label: 'Store',
                          value: order.store?.name ?? 'Store',
                        ),
                        SummaryLine(
                          label: 'Delivery fee',
                          value: peso(order.deliveryFee),
                        ),
                        SummaryLine(
                          label: 'Total',
                          value: peso(order.total),
                          bold: true,
                        ),
                        SummaryLine(
                          label: 'Payment',
                          value: order.paymentMethod,
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Column(
                    children: [
                      PrimaryAction(
                        label: 'Track order',
                        icon: Icons.location_on_rounded,
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          CustomerRoutes.orderTracking,
                          arguments: order,
                        ),
                      ),
                      const SizedBox(height: 9),
                      TextButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          CustomerRoutes.home,
                          (_) => false,
                        ),
                        child: const Text('Back to home'),
                      ),
                    ],
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

enum OrderStage {
  placed,
  confirmed,
  preparing,
  findingRider,
  assigned,
  pickedUp,
  outForDelivery,
  delivered,
  cancelled,
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
    OrderStage.cancelled => 'Order cancelled',
  };

  String get description => switch (this) {
    OrderStage.placed => 'Waiting for the store to confirm your order.',
    OrderStage.confirmed => 'The store accepted your order.',
    OrderStage.preparing => 'The store is preparing your items.',
    OrderStage.findingRider => 'Looking for an available nearby rider.',
    OrderStage.assigned => 'A rider has been assigned to your delivery.',
    OrderStage.pickedUp => 'Your order was picked up from the store.',
    OrderStage.outForDelivery => 'Your rider is heading to your address.',
    OrderStage.delivered => 'Your order has been delivered.',
    OrderStage.cancelled => 'This order will not be delivered.',
  };
}

OrderStage stageForStatus(String status) => switch (status) {
  'CONFIRMED' => OrderStage.confirmed,
  'PREPARING' => OrderStage.preparing,
  'READY_FOR_PICKUP' => OrderStage.findingRider,
  'RIDER_ASSIGNED' => OrderStage.assigned,
  'PICKED_UP' => OrderStage.pickedUp,
  'OUT_FOR_DELIVERY' => OrderStage.outForDelivery,
  'DELIVERED' => OrderStage.delivered,
  'CANCELLED' => OrderStage.cancelled,
  _ => OrderStage.placed,
};

Color colorForOrder(CustomerOrder order) => order.isCancelled
    ? danger
    : order.isDelivered
    ? success
    : order.isPending
    ? warning
    : sky;

String _trackingAge(DateTime recordedAt) {
  final age = DateTime.now().difference(recordedAt.toLocal());
  if (age.inSeconds < 10) return 'just now';
  if (age.inMinutes < 1) return '${age.inSeconds} seconds ago';
  if (age.inHours < 1) return '${age.inMinutes} minutes ago';
  return '${age.inHours} hours ago';
}

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key, this.order, this.orderId})
    : assert(order != null || orderId != null);

  final CustomerOrder? order;
  final int? orderId;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  Future<CustomerOrder>? future;
  CustomerRealtimeController? realtime;
  int seenOrderVersion = 0;
  int seenLocationVersion = 0;

  int get id => widget.order?.id ?? widget.orderId!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRealtime = CustomerDependencyScope.of(context).realtime;
    if (realtime != nextRealtime) {
      realtime?.removeListener(onRealtimeEvent);
      realtime = nextRealtime;
      seenOrderVersion = nextRealtime.orderVersion;
      seenLocationVersion = nextRealtime.locationVersion;
      nextRealtime.addListener(onRealtimeEvent);
    }
    future ??= loadOrder();
  }

  @override
  void dispose() {
    realtime?.removeListener(onRealtimeEvent);
    realtime?.watchDelivery(null);
    super.dispose();
  }

  Future<CustomerOrder> loadOrder() async {
    final order = await CustomerDependencyScope.of(context).orderRepository
        .get(id);
    if (mounted) {
      final delivery = order.delivery;
      realtime?.watchDelivery(
        delivery?.isTrackable == true ? delivery!.id : null,
      );
      seenLocationVersion = realtime?.locationVersion ?? seenLocationVersion;
    }
    return order;
  }

  void onRealtimeEvent() {
    final source = realtime!;
    if (source.locationVersion != seenLocationVersion) {
      seenLocationVersion = source.locationVersion;
      if (mounted) setState(() {});
    }
    if (source.orderVersion == seenOrderVersion) return;
    seenOrderVersion = source.orderVersion;
    if (source.lastOrderId == null || source.lastOrderId == id) reload();
  }

  void reload() => setState(() {
    future = loadOrder();
  });

  Future<void> cancel(CustomerOrder order) async {
    final repository = CustomerDependencyScope.of(context).orderRepository;
    final confirmed = await confirmAction(
      context,
      title: 'Cancel order?',
      body: 'Only pending orders can be cancelled.',
      confirmLabel: 'Cancel order',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final cancelled = await repository.cancel(order.id);
      if (!mounted) return;
      setState(() {
        future = Future.value(cancelled);
      });
      message(context, 'Order cancelled.', kind: ToastKind.success);
    } on CustomerApiException catch (error) {
      if (mounted) message(context, error.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar(
      'Order details',
      actions: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: FutureBuilder<CustomerOrder>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ApiErrorState(
            messageText: apiErrorMessage(snapshot.error),
            onRetry: reload,
          );
        }
        final order = snapshot.data!;
        final stage = stageForStatus(order.status);
        final delivery = order.delivery;
        final pushedLocation = realtime?.lastRiderLocation;
        final liveLocation = pushedLocation?.deliveryId == delivery?.id
            ? pushedLocation
            : delivery?.riderLocation;
        const timeline = [
          OrderStage.placed,
          OrderStage.confirmed,
          OrderStage.preparing,
          OrderStage.findingRider,
          OrderStage.assigned,
          OrderStage.pickedUp,
          OrderStage.outForDelivery,
          OrderStage.delivered,
        ];
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              TrackingHero(stage: stage),
              if (delivery != null) ...[
                const SizedBox(height: 14),
                CustomerDeliveryMap(
                  delivery: delivery,
                  liveRiderLocation: liveLocation,
                ),
                if (delivery.isTrackable) ...[
                  const SizedBox(height: 8),
                  Text(
                    liveLocation?.recordedAt == null
                        ? 'Waiting for the rider’s live location…'
                        : 'Rider location updated ${_trackingAge(liveLocation!.recordedAt!)}',
                    style: TextStyle(
                      color: appPaletteOf(context).quiet,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.store?.name ?? 'Store',
                      style: TextStyle(
                        color: appPaletteOf(context).text,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.orderNumber} • ${peso(order.total)}',
                      style: TextStyle(color: appPaletteOf(context).quiet),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.deliveryAddress,
                      style: TextStyle(color: appPaletteOf(context).quiet),
                    ),
                    if (!order.isCancelled) ...[
                      const SizedBox(height: 20),
                      ...timeline.map(
                        (item) => TimelineItem(
                          label: item.title,
                          complete: item.index < stage.index,
                          active: item == stage,
                          last: item == timeline.last,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const InfoBanner(
                icon: Icons.location_searching_rounded,
                text: 'Order status and rider location update automatically from Laravel.',
              ),
              if (order.isPending) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => cancel(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: danger,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: danger),
                  ),
                  child: const Text('Cancel order'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int tab = 0;
  Future<List<CustomerOrder>>? future;
  CustomerRealtimeController? realtime;
  int seenOrderVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRealtime = CustomerDependencyScope.of(context).realtime;
    if (realtime != nextRealtime) {
      realtime?.removeListener(onOrderEvent);
      realtime = nextRealtime;
      seenOrderVersion = nextRealtime.orderVersion;
      nextRealtime.addListener(onOrderEvent);
    }
    future ??= CustomerDependencyScope.of(context).orderRepository.list();
  }

  @override
  void dispose() {
    realtime?.removeListener(onOrderEvent);
    super.dispose();
  }

  void onOrderEvent() {
    if (realtime!.orderVersion == seenOrderVersion) return;
    seenOrderVersion = realtime!.orderVersion;
    reload();
  }

  void reload() => setState(() {
    future = CustomerDependencyScope.of(context).orderRepository.list();
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My orders',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
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
                onSelectionChanged: (value) =>
                    setState(() => tab = value.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<CustomerOrder>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ApiErrorState(
                  messageText: apiErrorMessage(snapshot.error),
                  onRetry: reload,
                );
              }
              final all = snapshot.data ?? const [];
              final orders = all
                  .where((order) {
                    if (tab == 1) return order.isDelivered;
                    if (tab == 2) return order.isCancelled;
                    return !order.isDelivered && !order.isCancelled;
                  })
                  .toList(growable: false);
              if (orders.isEmpty) {
                return EmptyState(
                  icon: tab == 0
                      ? Icons.receipt_long_outlined
                      : tab == 1
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  title: tab == 0
                      ? 'No active orders'
                      : tab == 1
                      ? 'No completed orders'
                      : 'No cancelled orders',
                  subtitle: 'Orders from Laravel will appear here.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  reload();
                  await future;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderHistoryCard(
                      store: order.store?.name ?? 'Store',
                      id: order.orderNumber,
                      total: peso(order.total),
                      status: order.statusLabel.toUpperCase(),
                      color: colorForOrder(order),
                      date: shortDate(order.createdAt),
                      onTap: () => Navigator.pushNamed(
                        context,
                        CustomerRoutes.orderTracking,
                        arguments: order,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
