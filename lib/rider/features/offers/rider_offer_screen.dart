part of '../../app.dart';

class RiderIncomingOfferSheet extends StatefulWidget {
  const RiderIncomingOfferSheet({
    super.key,
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onExpired,
  });

  static const countdownDuration = Duration(seconds: 12);

  final RiderOffer offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onExpired;

  @override
  State<RiderIncomingOfferSheet> createState() =>
      _RiderIncomingOfferSheetState();
}

class _RiderIncomingOfferSheetState extends State<RiderIncomingOfferSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _countdown =
        AnimationController(
            vsync: this,
            duration: RiderIncomingOfferSheet.countdownDuration,
            value: 1,
          )
          ..addStatusListener((status) {
            if (status != AnimationStatus.dismissed || _expired) return;
            _expired = true;
            widget.onExpired();
          })
          ..reverse();
  }

  @override
  void didUpdateWidget(RiderIncomingOfferSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.id == widget.offer.id) return;
    _expired = false;
    _countdown
      ..stop()
      ..value = 1
      ..reverse();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.offer.delivery;
    final palette = riderPaletteOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: palette.surface,
      elevation: 18,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _countdown,
              builder: (context, _) => LinearProgressIndicator(
                minHeight: 5,
                value: _countdown.value,
                color: palette.urgent,
                backgroundColor: palette.line,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEW DELIVERY OFFER',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .8,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              delivery.displayNumber,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        riderMoney(delivery.riderCommission),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: palette.ratingStar),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _OfferStop(
                    icon: Icons.storefront_rounded,
                    color: scheme.primary,
                    title: delivery.store?.name ?? 'Pickup store',
                    subtitle:
                        'Pickup · ${delivery.distanceKm.toStringAsFixed(1)} km route',
                  ),
                  const SizedBox(height: 13),
                  _OfferStop(
                    icon: Icons.location_on_rounded,
                    color: palette.ratingStar,
                    title: delivery.order?.customerName ?? 'Customer',
                    subtitle:
                        'Drop-off · ${delivery.deliveryAddress.isEmpty ? 'Address unavailable' : delivery.deliveryAddress}',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label:
                              'Reject ${riderMoney(delivery.riderCommission)} offer from ${delivery.store?.name ?? 'store'}',
                          child: OutlinedButton(
                            onPressed: widget.busy ? null : widget.onReject,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label:
                              'Accept ${riderMoney(delivery.riderCommission)} offer from ${delivery.store?.name ?? 'store'}',
                          child: RiderGradientButton(
                            label: widget.busy ? 'Accepting…' : 'Accept',
                            onPressed: widget.busy ? null : widget.onAccept,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferStop extends StatelessWidget {
  const _OfferStop({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Row(
      children: [
        IconTile(icon: icon, color: color, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
