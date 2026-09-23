part of '../../app.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller});
  final RiderAppController controller;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;

  List<RiderDelivery> get filtered {
    final period = widget.controller.earningsSummary?.period(filter);
    if (period != null) {
      return widget.controller.completedDeliveries
          .where((delivery) => period.includes(delivery.deliveredAt))
          .toList();
    }
    final now = DateTime.now();
    return widget.controller.completedDeliveries.where((delivery) {
      final date = delivery.deliveredAt?.toLocal();
      if (date == null) return filter == 2;
      return switch (filter) {
        0 =>
          date.year == now.year &&
              date.month == now.month &&
              date.day == now.day,
        1 => !date.isAfter(now) && now.difference(date).inDays < 7,
        _ => date.year == now.year && date.month == now.month,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = filtered;
    final earnings =
        widget.controller.earningsSummary?.period(filter).earnings ??
        deliveries.fold<double>(0, (sum, item) => sum + item.riderCommission);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: widget.controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            Text(
              'Earnings & history',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text('Live totals based on completed backend deliveries.'),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [blue, Color(0xFF0065D8)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERIOD EARNINGS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    riderMoney(earnings),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 38,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${deliveries.length} completed deliveries',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Today')),
                ButtonSegment(value: 1, label: Text('Week')),
                ButtonSegment(value: 2, label: Text('Month')),
              ],
              selected: {filter},
              onSelectionChanged: (value) =>
                  setState(() => filter = value.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 24),
            if (deliveries.isEmpty)
              const RiderEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No completed deliveries',
                message:
                    'Completed deliveries for this period will appear here.',
              )
            else
              ...deliveries.map(
                (delivery) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DeliveryRow(delivery: delivery),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
