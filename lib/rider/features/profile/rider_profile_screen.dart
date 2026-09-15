part of '../../app.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});
  final RiderAppController controller;

  Future<void> _logout(BuildContext context) async {
    final confirmed = await confirmRiderAction(
      context,
      title: 'End your rider session?',
      body: 'You will stop receiving delivery offers after logout.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    if (controller.profile?.isOnline == true &&
        controller.activeDelivery == null) {
      await controller.setOnline(false);
    }
    await controller.logout();
    if (!context.mounted) return;
    RiderRouteScope.of(context).signOut();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(RiderRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final palette = riderPaletteOf(context);
    final theme = RiderThemeScope.of(context);
    if (profile == null) {
      return RiderEmptyState(
        icon: Icons.person_off_outlined,
        title: 'Profile unavailable',
        message: controller.errorMessage ?? 'Retry loading your rider profile.',
        action: 'Retry',
        onAction: controller.refresh,
      );
    }
    final initials = profile.user.name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: palette.softBlue,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: blue,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile.user.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    profile.status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: profile.canGoOnline ? green : orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ProfileDetail(
                          label: 'PHONE',
                          value: profile.user.phone ?? 'Not set',
                        ),
                      ),
                      Expanded(
                        child: ProfileDetail(
                          label: 'RIDER ID',
                          value: 'RDR-${profile.id.toString().padLeft(4, '0')}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ProfileDetail(
                          label: 'VEHICLE',
                          value: profile.vehicleType.replaceAll('_', ' '),
                        ),
                      ),
                      Expanded(
                        child: ProfileDetail(
                          label: 'PLATE',
                          value: profile.vehiclePlate ?? 'Not set',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_suggest_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {theme.mode},
              onSelectionChanged: (modes) => theme.setMode(modes.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 18),
            MenuTile(
              icon: Icons.mail_outline_rounded,
              title: profile.user.email,
              subtitle: 'Account email',
            ),
            const SizedBox(height: 10),
            MenuTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              destructive: true,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 24),
            Text(
              'TalaDelivery Rider • Version 1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
