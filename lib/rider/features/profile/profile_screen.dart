part of '../../app.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Color(0xFFDCEEFF),
                  child: Text(
                    'JD',
                    style: TextStyle(
                      color: blue,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Juan Dela Cruz',
                  style: TextStyle(
                    fontSize: 21,
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verified TalaDelivery Rider',
                  style: TextStyle(color: green, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 22),
                Divider(),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ProfileDetail(
                        label: 'PHONE',
                        value: '0917 123 4567',
                      ),
                    ),
                    Expanded(
                      child: ProfileDetail(
                        label: 'RIDER ID',
                        value: 'RDR-0184',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ProfileDetail(
                        label: 'VEHICLE',
                        value: 'Motorcycle',
                      ),
                    ),
                    Expanded(
                      child: ProfileDetail(label: 'PLATE', value: 'ABC-1234'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const MenuTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit profile',
          ),
          const SizedBox(height: 10),
          const MenuTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change password',
          ),
          const SizedBox(height: 10),
          const MenuTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & support',
          ),
          const SizedBox(height: 10),
          MenuTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            destructive: true,
            onTap: () async {
              final confirmed = await confirmRiderAction(
                context,
                title: 'End your rider session?',
                body: 'You will stop receiving delivery offers after logout.',
                confirmLabel: 'Log out',
                destructive: true,
              );
              if (context.mounted && confirmed) {
                Navigator.of(context).pushAndRemoveUntil(
                  fadeRoute(const LoginScreen()),
                  (_) => false,
                );
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'TalaDelivery Rider • Version 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
