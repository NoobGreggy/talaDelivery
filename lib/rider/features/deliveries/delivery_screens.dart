part of '../../app.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key});
  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  DeliveryStage stage = DeliveryStage.accepted;
  bool cashReceived = false;
  String get status => switch (stage) {
    DeliveryStage.accepted => 'Heading to pickup',
    DeliveryStage.arrived => 'At pickup',
    DeliveryStage.pickedUp => 'Order picked up',
    DeliveryStage.inTransit => 'On the way to customer',
  };
  String get button => switch (stage) {
    DeliveryStage.accepted => 'I’ve arrived at store',
    DeliveryStage.arrived => 'Mark as picked up',
    DeliveryStage.pickedUp => 'Start delivery',
    DeliveryStage.inTransit => 'Mark as delivered',
  };

  void advance() {
    if (stage == DeliveryStage.inTransit) {
      if (!cashReceived) {
        return showMessage(context, 'Confirm the cash payment first.');
      }
      showCompletionSheet();
    } else {
      final nextStage = DeliveryStage.values[stage.index + 1];
      setState(() => stage = nextStage);
      final toast = switch (nextStage) {
        DeliveryStage.arrived => 'Arrival at the store confirmed.',
        DeliveryStage.pickedUp => 'Order marked as picked up.',
        DeliveryStage.inTransit => 'Delivery started. Drive safely!',
        DeliveryStage.accepted => 'Delivery accepted.',
      };
      showMessage(context, toast, kind: RiderToastKind.success);
    }
  }

  Future<void> showCompletionSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD8E0E8),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 22),
          const IconTile(
            icon: Icons.check_circle_rounded,
            color: green,
            size: 58,
          ),
          const SizedBox(height: 16),
          Text(
            'Complete delivery?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Order #TD-100001 • ₱399 cash collected',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Confirm delivery',
            icon: Icons.check_rounded,
            onPressed: () {
              Navigator.pop(sheetContext);
              showMessage(
                context,
                'Delivery completed successfully.',
                kind: RiderToastKind.success,
              );
              Navigator.of(context)
                  .pushReplacement(fadeRoute(const DeliveryCompleteScreen()));
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Not yet'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final atCustomer =
        stage == DeliveryStage.pickedUp || stage == DeliveryStage.inTransit;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery #TD-100001',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text('ABC Mini Mart', style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusBanner(status: status, stage: stage.index + 1),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 210,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: const CustomPaint(
                        painter: RouteMapPainter(),
                        child: Center(child: RiderMapPin()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LocationCard(
                    eyebrow: atCustomer ? 'DELIVER TO' : 'PICK UP FROM',
                    title: atCustomer ? 'Juan Dela Cruz' : 'ABC Mini Mart',
                    address: atCustomer
                        ? '123 Example Street\nCabanatuan City'
                        : '123 Main Street\nCabanatuan City',
                    icon: atCustomer
                        ? Icons.home_rounded
                        : Icons.storefront_rounded,
                    trailing: atCustomer ? '4.8 km' : '2.3 km',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryAction(
                          icon: Icons.navigation_rounded,
                          label: 'Navigate',
                          onTap: () => showMessage(
                            context,
                            'Google Maps would open here.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SecondaryAction(
                          icon: atCustomer
                              ? Icons.call_rounded
                              : Icons.chat_bubble_outline_rounded,
                          label: atCustomer ? 'Call' : 'Message',
                          onTap: () => showMessage(
                            context,
                            atCustomer
                                ? 'Calling customer…'
                                : 'Opening messages…',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (stage == DeliveryStage.arrived) ...[
                    const SizedBox(height: 16),
                    const PickupCodeCard(),
                  ],
                  if (atCustomer) ...[
                    const SizedBox(height: 16),
                    CodCard(
                      checked: cashReceived,
                      onChanged: (value) {
                        setState(() => cashReceived = value ?? false);
                        showMessage(
                          context,
                          value == true
                              ? 'Cash payment confirmed.'
                              : 'Cash confirmation removed.',
                          kind: value == true
                              ? RiderToastKind.success
                              : RiderToastKind.warning,
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  const OrderNotesCard(),
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            child: PrimaryButton(
              label: button,
              icon: Icons.arrow_forward_rounded,
              onPressed: advance,
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryCompleteScreen extends StatelessWidget {
  const DeliveryCompleteScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 118,
              height: 118,
              decoration: const BoxDecoration(
                color: Color(0xFFE2F8ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: green, size: 64),
            ),
            const SizedBox(height: 28),
            Text(
              'Delivery completed!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Great work, Juan. You’re back online and ready for the next one.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CompletionStat(label: 'EARNED', value: '₱69'),
                  SizedBox(height: 42, child: VerticalDivider()),
                  CompletionStat(label: 'COLLECTED', value: '₱399'),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(label: 'Done', onPressed: null),
          ],
        ),
      ),
    ),
  );
}
