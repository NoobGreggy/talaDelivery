part of '../../app.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _editProfile() async {
    final updated = await Navigator.pushNamed(
      context,
      CustomerRoutes.editProfile,
    );
    if (mounted && updated is CustomerUser) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = CustomerRouteScope.of(context).session.user;
    final name = user?.name ?? 'Customer';
    final palette = appPaletteOf(context);
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          InfoCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: palette.avatarFill,
                  child: Text(
                    initials.isEmpty ? 'CU' : initials,
                    style: const TextStyle(
                      color: sky,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      if (user?.phone != null)
                        Text(
                          user!.phone!,
                          style: TextStyle(color: palette.quiet),
                        ),
                      if (user != null)
                        Text(
                          user.email,
                          style: TextStyle(color: palette.quiet, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_rounded, color: sky),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ProfileTile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            onTap: _editProfile,
          ),
          const SizedBox(height: 10),
          ProfileTile(
            icon: Icons.location_on_outlined,
            title: 'My addresses',
            onTap: () => Navigator.pushNamed(context, CustomerRoutes.addresses),
          ),
          const SizedBox(height: 10),
          ProfileTile(
            icon: Icons.receipt_long_outlined,
            title: 'My orders',
            onTap: () => Navigator.pushNamed(context, CustomerRoutes.orders),
          ),
          const SizedBox(height: 10),
          ProfileTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () =>
                Navigator.pushNamed(context, CustomerRoutes.notifications),
          ),
          const SizedBox(height: 24),
          SectionHeading(title: 'Appearance'),
          const SizedBox(height: 12),
          InfoCard(
            child: ListenableBuilder(
              listenable: ThemeScope.of(context),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(
                      color: sky,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Follow the system or choose a fixed appearance.',
                    style: TextStyle(color: palette.quiet, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {ThemeScope.of(context).mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        ThemeScope.of(context).mode = selection.first,
                  ),
                ],
              ),
            ),
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
                body: 'You’ll need to sign in again to place orders.',
                confirmLabel: 'Log out',
                destructive: true,
              );
              if (context.mounted && confirmed) {
                try {
                  await CustomerDependencyScope.of(context).authRepository
                      .logout();
                } catch (_) {
                  // Local logout must still complete if the API is unavailable.
                }
                if (!context.mounted) return;
                CustomerDependencyScope.of(context).cartController.clear();
                CustomerRouteScope.of(context).signOut();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(CustomerRoutes.login, (_) => false);
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            'TalaDelivery • Version 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.quiet, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
