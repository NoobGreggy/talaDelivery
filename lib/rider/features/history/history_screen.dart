part of '../../app.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Earnings & history',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          const Text('Your delivery performance at a glance.'),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [blue, Color(0xFF0065D8)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY’S EARNINGS',
                  style: TextStyle(
                    color: Color(0xFFDDF0FF),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₱540',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 38,
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: LightStat(label: 'This week', value: '₱3,240'),
                    ),
                    Expanded(
                      child: LightStat(label: 'Completed', value: '42'),
                    ),
                  ],
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
            onSelectionChanged: (value) => setState(() => filter = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Completed deliveries'),
          const SizedBox(height: 14),
          const DeliveryRow(
            store: 'ABC Mini Mart',
            id: '#TD-100001',
            time: '10:42 AM',
            fee: '₱69',
          ),
          const SizedBox(height: 10),
          const DeliveryRow(
            store: 'XYZ Grocery',
            id: '#TD-099984',
            time: '9:30 AM',
            fee: '₱59',
          ),
          const SizedBox(height: 10),
          const DeliveryRow(
            store: 'Bayan Pharmacy',
            id: '#TD-099961',
            time: '8:15 AM',
            fee: '₱72',
          ),
        ],
      ),
    ),
  );
}
