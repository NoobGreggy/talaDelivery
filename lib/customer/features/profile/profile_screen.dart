part of '../../app.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        InfoCard(
          child: const Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFE2F1FD),
                child: Text(
                  'GG',
                  style: TextStyle(
                    color: sky,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gregg Garcia',
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text('0917 123 4567', style: TextStyle(color: quiet)),
                    Text(
                      'gregg@example.com',
                      style: TextStyle(color: quiet, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.verified_rounded, color: sky),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ProfileTile(
          icon: Icons.person_outline_rounded,
          title: 'My profile',
          onTap: () => message(context, 'Profile editor is static for now.'),
        ),
        const SizedBox(height: 10),
        ProfileTile(
          icon: Icons.location_on_outlined,
          title: 'My addresses',
          onTap: () => Navigator.push(context, slide(const AddressesPage())),
        ),
        const SizedBox(height: 10),
        ProfileTile(
          icon: Icons.receipt_long_outlined,
          title: 'My orders',
          onTap: () =>
              message(context, 'Use the Orders tab to view your orders.'),
        ),
        const SizedBox(height: 10),
        ProfileTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          onTap: () =>
              Navigator.push(context, slide(const NotificationsPage())),
        ),
        const SizedBox(height: 10),
        ProfileTile(
          icon: Icons.help_outline_rounded,
          title: 'Help',
          onTap: () => message(context, 'Help center is static for now.'),
        ),
        const SizedBox(height: 10),
        ProfileTile(
          icon: Icons.logout_rounded,
          title: 'Log out',
          destructive: true,
          onTap: () async {
            final confirmed = await confirmAction(
              context,
              title: 'Log out?',
              body: 'You’ll need to sign in again to place and track orders.',
              confirmLabel: 'Log out',
              destructive: true,
            );
            if (context.mounted && confirmed) {
              Navigator.of(context)
                  .pushAndRemoveUntil(fade(const LoginPage()), (_) => false);
            }
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'TalaDelivery • Version 1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(color: quiet, fontSize: 12),
        ),
      ],
    ),
  );
}
