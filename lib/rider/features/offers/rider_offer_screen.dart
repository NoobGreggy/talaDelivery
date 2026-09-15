part of '../../app.dart';

class OfferScreen extends StatefulWidget {
  const OfferScreen({super.key, this.offer});
  final RiderOffer? offer;

  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  Timer? timer;
  late int seconds;

  RiderOffer? get offer =>
      widget.offer ??
      RiderDependencyScope.of(context).controller.offers.firstOrNull;

  @override
  void initState() {
    super.initState();
    seconds = widget.offer?.secondsRemaining ?? 0;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = offer;
      setState(() => seconds = current?.secondsRemaining ?? 0);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _accept(RiderOffer value) async {
    final controller = RiderDependencyScope.of(context).controller;
    final delivery = await controller.accept(value);
    if (!mounted) return;
    if (delivery == null) {
      showMessage(
        context,
        controller.errorMessage ?? 'Offer could not be accepted.',
      );
      return;
    }
    final routes = RiderRouteScope.of(context)..startDelivery();
    routes.sync(controller);
    Navigator.of(context)
        .pushReplacementNamed(RiderRoutes.activeDelivery, arguments: delivery);
  }

  Future<void> _reject(RiderOffer value) async {
    final confirmed = await confirmRiderAction(
      context,
      title: 'Reject this offer?',
      body: 'The delivery will be offered to another nearby rider.',
      confirmLabel: 'Reject offer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final controller = RiderDependencyScope.of(context).controller;
    final success = await controller.reject(value);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      showMessage(
        context,
        controller.errorMessage ?? 'Offer could not be rejected.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = RiderDependencyScope.of(context).controller;
    final value = offer;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery offers')),
        body: RiderEmptyState(
          icon: Icons.inbox_outlined,
          title: 'No live offers',
          message:
              'New offers from the backend will appear while you are online.',
          action: 'Refresh',
          onAction: () async {
            await controller.refresh();
            if (mounted) setState(() {});
          },
        ),
      );
    }
    final delivery = value.delivery;
    final expired = seconds <= 0;
    return Scaffold(
      appBar: AppBar(title: const Text('New delivery')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Center(
            child: SizedBox.square(
              dimension: 106,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: seconds == 0 ? 0 : (seconds / 120).clamp(0, 1),
                    strokeWidth: 8,
                    color: expired ? riderPaletteOf(context).muted : blue,
                  ),
                  Center(
                    child: Text(
                      expired ? 'Expired' : '${seconds}s',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${riderMoney(delivery.deliveryFee)} estimated earnings',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${delivery.distanceKm.toStringAsFixed(1)} km total',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          RouteCard(delivery: delivery),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MiniInfo(
                  icon: Icons.route_rounded,
                  label: 'Distance',
                  value: '${delivery.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniInfo(
                  icon: Icons.payments_outlined,
                  label: 'Payment',
                  value:
                      '${delivery.order?.paymentMethod ?? 'COD'} ${riderMoney(delivery.order?.total ?? 0)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (!expired) ...[
            PrimaryButton(
              label: controller.isSubmitting ? 'Accepting…' : 'Accept delivery',
              icon: Icons.check_rounded,
              onPressed: controller.isSubmitting ? null : () => _accept(value),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: controller.isSubmitting ? null : () => _reject(value),
              child: const Text('Reject'),
            ),
          ] else
            PrimaryButton(
              label: 'Back to dashboard',
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
