part of '../../app.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key, this.delivery});
  final RiderDelivery? delivery;

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  bool cashReceived = false;

  RiderDelivery? get delivery =>
      RiderDependencyScope.of(context).controller.activeDelivery ??
      widget.delivery;

  String _status(String status) => switch (status) {
    'ASSIGNED' => 'Heading to pickup',
    'ACCEPTED' => 'At pickup',
    'PICKED_UP' => 'Order picked up',
    'IN_TRANSIT' => 'On the way to customer',
    _ => status.replaceAll('_', ' ').toLowerCase(),
  };

  String _button(String status) => switch (status) {
    'ASSIGNED' => 'I’ve arrived at store',
    'ACCEPTED' => 'Mark as picked up',
    'PICKED_UP' => 'Start delivery',
    'IN_TRANSIT' => 'Mark as delivered',
    _ => 'Refresh delivery',
  };

  String _action(String status) => switch (status) {
    'ASSIGNED' => 'arrived',
    'ACCEPTED' => 'pickup',
    'PICKED_UP' => 'start',
    'IN_TRANSIT' => 'complete',
    _ => '',
  };

  Future<void> _advance(RiderDelivery value) async {
    if (value.status == 'IN_TRANSIT' &&
        value.order?.paymentMethod == 'COD' &&
        !cashReceived) {
      showMessage(context, 'Confirm that cash was received first.');
      return;
    }
    final action = _action(value.status);
    if (action.isEmpty) return;
    final controller = RiderDependencyScope.of(context).controller;
    final updated = await controller.advanceDelivery(action);
    if (!mounted) return;
    if (updated == null) {
      showMessage(
        context,
        controller.errorMessage ?? 'Delivery could not be updated.',
      );
      return;
    }
    if (updated.isDelivered) {
      RiderRouteScope.of(context).completeDelivery();
      Navigator.of(
        context,
      ).pushReplacementNamed(RiderRoutes.deliveryComplete, arguments: updated);
      return;
    }
    RiderRouteScope.of(context).sync(controller);
    showMessage(
      context,
      'Delivery status updated.',
      kind: RiderToastKind.success,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = RiderDependencyScope.of(context).controller;
    final value = delivery;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active delivery')),
        body: const RiderEmptyState(
          icon: Icons.route_outlined,
          title: 'No active delivery',
          message: 'Accept an offer before opening this page.',
        ),
      );
    }
    final atCustomer =
        value.status == 'PICKED_UP' || value.status == 'IN_TRANSIT';
    final palette = riderPaletteOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.displayNumber,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              value.store?.name ?? 'Delivery',
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.softBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const IconTile(
                        icon: Icons.delivery_dining_rounded,
                        color: blue,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _status(value.status),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (controller.isSubmitting)
                        const CircularProgressIndicator(strokeWidth: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RiderDeliveryMap(delivery: value),
                const SizedBox(height: 16),
                RouteCard(delivery: value),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        atCustomer ? 'DELIVER TO' : 'PICK UP FROM',
                        style: const TextStyle(
                          color: blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        atCustomer
                            ? value.order?.customerName ?? 'Customer'
                            : value.store?.name ?? 'Store',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        atCustomer
                            ? value.deliveryAddress
                            : value.pickupAddress,
                      ),
                      if (atCustomer && value.order?.customerPhone != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          value.order!.customerPhone!,
                          style: const TextStyle(color: blue),
                        ),
                      ],
                    ],
                  ),
                ),
                if (atCustomer && value.order?.paymentMethod == 'COD') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.softGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: cashReceived,
                      onChanged: (checked) =>
                          setState(() => cashReceived = checked ?? false),
                      title: Text(
                        'Cash received: ${riderMoney(value.order?.total ?? 0)}',
                      ),
                      subtitle: const Text(
                        'Confirm only after receiving the payment.',
                      ),
                    ),
                  ),
                ],
                if (value.order?.notes != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text(value.order!.notes!)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            color: palette.surface,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            child: PrimaryButton(
              label: controller.isSubmitting
                  ? 'Updating…'
                  : _button(value.status),
              icon: Icons.arrow_forward_rounded,
              onPressed: controller.isSubmitting ? null : () => _advance(value),
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryCompleteScreen extends StatelessWidget {
  const DeliveryCompleteScreen({super.key, this.delivery});
  final RiderDelivery? delivery;
  @override
  Widget build(BuildContext context) {
    final value = delivery;
    final palette = riderPaletteOf(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.check_circle_rounded, color: green, size: 110),
              const SizedBox(height: 28),
              Text(
                'Delivery completed!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                value?.displayNumber ??
                    'The delivery was confirmed by the server.',
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CompletionStat(
                      label: 'EARNED',
                      value: riderMoney(value?.riderCommission ?? 0),
                    ),
                    const SizedBox(height: 42, child: VerticalDivider()),
                    _CompletionStat(
                      label: 'COLLECTED',
                      value: riderMoney(value?.order?.total ?? 0),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  RiderRouteScope.of(context).finishDelivery();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    RiderRoutes.dashboard,
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  const _CompletionStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
