part of '../../app.dart';

class RiderWalletScreen extends StatefulWidget {
  const RiderWalletScreen({super.key});
  @override
  State<RiderWalletScreen> createState() => _RiderWalletScreenState();
}

class _RiderWalletScreenState extends State<RiderWalletScreen> {
  RiderWalletController? _controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= RiderWalletController(
      RiderDependencyScope.of(context).repository,
    )..refresh();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final palette = riderPaletteOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tala Coins')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            children: [
              if (controller.isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        RiderCoinImage(size: 48),
                        SizedBox(width: 12),
                        Expanded(child: Text('Available Tala Coins')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.wallet == null
                          ? '—'
                          : riderCoins(controller.wallet!.availableTokens),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Delivery deductions use your delivery zone’s configured rate. Contact the platform administrator to arrange a top-up.',
                    ),
                    if (controller.wallet?.availableTokens.startsWith('-') ==
                        true) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Your balance is negative. Please contact the platform administrator.',
                        style: TextStyle(color: orange),
                      ),
                    ],
                  ],
                ),
              ),
              if (controller.error != null)
                _retry(controller.error!, controller.refresh),
              const SizedBox(height: 22),
              Text(
                'Transaction History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (controller.historyError != null)
                _retry(controller.historyError!, controller.refresh),
              if (!controller.isLoading &&
                  controller.historyError == null &&
                  controller.transactions.isEmpty)
                const RiderEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No wallet activity yet',
                  message:
                      'Your top-ups and delivery deductions will appear here.',
                ),
              ...controller.transactions.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              entry.isDebit
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline,
                              color: entry.isDebit ? orange : green,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${entry.isDebit ? '' : '+'}${riderCoins(entry.amount)} coins',
                          style: TextStyle(
                            color: entry.isDebit ? orange : green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          entry.deliveryId == null
                              ? 'Transaction #${entry.id}'
                              : 'Delivery #${entry.deliveryId}',
                        ),
                        if (entry.note != null) Text(entry.note!),
                        if (entry.createdAt != null)
                          Text(
                            '${riderDate(entry.createdAt)} • ${TimeOfDay.fromDateTime(entry.createdAt!.toLocal()).format(context)}',
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Completed • Balance after: ${riderCoins(entry.balanceAfter)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (controller.hasMore)
                TextButton(
                  onPressed: controller.isLoadingMore || controller.isLoading
                      ? null
                      : controller.loadMore,
                  child: Text(
                    controller.isLoadingMore ? 'Loading…' : 'Load more',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _retry(String message, Future<void> Function() retry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        TextButton(
          onPressed: _controller!.isLoading ? null : retry,
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
