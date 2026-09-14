part of '../../app.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.online,
    required this.onToggle,
    required this.onOffer,
    required this.onEarnings,
  });
  final bool online;
  final VoidCallback onToggle;
  final VoidCallback onOffer;
  final VoidCallback onEarnings;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RiderLogo(size: 48),
              const SizedBox(width: 10),
              const Expanded(child: BrandLockup(compact: true)),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Good morning,', style: Theme.of(context).textTheme.bodyLarge),
          Text('Juan!', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: online
                    ? const [Color(0xFF0E95FB), Color(0xFF0667DD)]
                    : const [Color(0xFF17283D), navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: (online ? blue : navy).withValues(alpha: .2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF7CFFBA)
                            : const Color(0xFFB9C4D0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      online ? 'YOU’RE ONLINE' : 'YOU’RE OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  online
                      ? 'Ready for your\nnext delivery?'
                      : 'Start your shift\nwhen you’re ready.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  online
                      ? 'We’re looking for nearby orders.'
                      : 'Location sharing starts only while online.',
                  style: const TextStyle(color: Color(0xFFD6E7F8), height: 1.4),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: online ? navy : blue,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    onToggle();
                    showMessage(
                      context,
                      online
                          ? 'You are now offline.'
                          : 'You are online and ready for deliveries.',
                      kind: RiderToastKind.success,
                    );
                  },
                  icon: Icon(
                    online
                        ? Icons.power_settings_new_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    online ? 'Go offline' : 'Go online',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (online) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: onOffer,
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFB9DEFF)),
                ),
                child: const Row(
                  children: [
                    IconTile(icon: Icons.delivery_dining_rounded, color: blue),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Demo delivery available',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Tap to preview the rider offer flow',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: blue),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          SectionTitle(
            title: 'Today’s overview',
            action: 'View earnings',
            onAction: onEarnings,
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.route_rounded,
                  value: '8',
                  label: 'Deliveries',
                  iconColor: blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.check_circle_rounded,
                  value: '6',
                  label: 'Completed',
                  iconColor: green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const EarningsCard(),
          const SizedBox(height: 28),
          const SectionTitle(title: 'Recent activity'),
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
        ],
      ),
    ),
  );
}
