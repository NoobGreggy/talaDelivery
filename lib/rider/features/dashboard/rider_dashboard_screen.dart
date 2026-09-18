part of '../../app.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onOffer,
    required this.onEarnings,
  });

  final RiderAppController controller;
  final VoidCallback onOffer;
  final VoidCallback onEarnings;

  Future<void> _toggle(BuildContext context) async {
    final profile = controller.profile;
    if (profile == null) return;
    final success = await controller.setOnline(!profile.isOnline);
    if (!context.mounted) return;
    RiderRouteScope.of(context).sync(controller);
    showMessage(
      context,
      success
          ? (controller.profile!.isOnline
                ? 'You are online and ready for deliveries.'
                : 'You are now offline.')
          : controller.errorMessage ?? 'Availability could not be updated.',
      kind: success ? RiderToastKind.success : RiderToastKind.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final palette = riderPaletteOf(context);
    if (controller.isLoading && profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile == null) {
      return RiderEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Rider data unavailable',
        message:
            controller.errorMessage ??
            'Pull your profile from the server again.',
        action: 'Retry',
        onAction: controller.refresh,
      );
    }
    final completed = controller.completedDeliveries;
    final today = DateTime.now();
    final todayDeliveries = completed.where((delivery) {
      final date = delivery.createdAt?.toLocal();
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).toList();
    final todayEarnings = todayDeliveries.fold<double>(
      0,
      (sum, delivery) => sum + delivery.deliveryFee,
    );
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              children: [
                const RiderLogo(size: 48),
                const SizedBox(width: 10),
                const Expanded(child: BrandLockup(compact: true)),
                if (controller.isLoading)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(RiderRoutes.notifications),
                    icon: Badge.count(
                      count: controller.unreadNotificationCount,
                      isLabelVisible: controller.unreadNotificationCount > 0,
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Welcome back,', style: Theme.of(context).textTheme.bodyLarge),
            Text(
              profile.user.name,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Account status: ${profile.status.replaceAll('_', ' ').toLowerCase()}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            _AvailabilityCard(
              profile: profile,
              busy: controller.isSubmitting,
              onToggle: () => _toggle(context),
            ),
            if (profile.isOnline) ...[
              const SizedBox(height: 16),
              if (controller.activeDelivery != null)
                RiderNoticeCard(
                  icon: Icons.navigation_rounded,
                  title:
                      'Active delivery ${controller.activeDelivery!.displayNumber}',
                  message:
                      'Continue the delivery from its current server status.',
                  onTap: () => Navigator.of(context).pushNamed(
                    RiderRoutes.activeDelivery,
                    arguments: controller.activeDelivery,
                  ),
                )
              else if (controller.offers.isNotEmpty)
                RiderNoticeCard(
                  icon: Icons.delivery_dining_rounded,
                  title:
                      '${controller.offers.length} delivery offer${controller.offers.length == 1 ? '' : 's'}',
                  message: 'Review the newest live offer.',
                  onTap: onOffer,
                )
              else
                RiderNoticeCard(
                  icon: Icons.radar_rounded,
                  title: 'Searching nearby',
                  message: 'No active offers yet. Pull down to refresh.',
                  onTap: controller.refresh,
                ),
            ],
            const SizedBox(height: 28),
            SectionTitle(
              title: 'Today’s overview',
              action: 'View history',
              onAction: onEarnings,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.route_rounded,
                    value: '${todayDeliveries.length}',
                    label: 'Today',
                    iconColor: blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.check_circle_rounded,
                    value: '${completed.length}',
                    label: 'All completed',
                    iconColor: green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            EarningsCard(amount: todayEarnings),
            const SizedBox(height: 28),
            const SectionTitle(title: 'Recent activity'),
            const SizedBox(height: 14),
            if (completed.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('Completed deliveries will appear here.'),
              )
            else
              ...completed
                  .take(3)
                  .map(
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

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.profile,
    required this.busy,
    required this.onToggle,
  });
  final RiderProfile profile;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: profile.isOnline
            ? const [Color(0xFF0E95FB), Color(0xFF0667DD)]
            : const [Color(0xFF17283D), navy],
      ),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          profile.isOnline ? 'YOU’RE ONLINE' : 'YOU’RE OFFLINE',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.isOnline
              ? 'Ready for your next delivery?'
              : profile.canGoOnline
              ? 'Start your shift when ready.'
              : 'Approval is required before going online.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: profile.isOnline ? navy : blue,
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: busy || (!profile.isOnline && !profile.canGoOnline)
              ? null
              : onToggle,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  profile.isOnline
                      ? Icons.power_settings_new
                      : Icons.play_arrow,
                ),
          label: Text(profile.isOnline ? 'Go offline' : 'Go online'),
        ),
      ],
    ),
  );
}
