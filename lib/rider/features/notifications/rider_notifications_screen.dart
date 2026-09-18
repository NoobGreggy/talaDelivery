part of '../../app.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RiderDependencyScope.of(context).controller;
    final notifications = controller.notifications;
    final unread = controller.unreadNotificationCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          unread > 0 ? 'Notifications ($unread new)' : 'Notifications',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  RiderEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No notifications yet',
                    message: 'Delivery updates and important alerts will appear here.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _NotificationTile(notification: notifications[index]),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final RiderNotification notification;

  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    final unread = !notification.isRead;
    return Material(
      color: unread ? palette.softBlue : palette.surface,
      child: ListTile(
        onTap: () {
          final controller = RiderDependencyScope.of(context).controller;
          controller.markNotificationRead(notification.id);
        },
        leading: CircleAvatar(
          backgroundColor: unread ? blue : palette.surface,
          foregroundColor: unread ? Colors.white : palette.muted,
          child: Icon(_iconFor(notification.type), size: 22),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              notification.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (notification.createdAt != null)
              Text(
                _relativeTime(notification.createdAt!),
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        trailing: unread
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  IconData _iconFor(String? type) => switch (type) {
    'offer' => Icons.local_offer_rounded,
    'delivery' => Icons.delivery_dining_rounded,
    'payment' => Icons.account_balance_wallet_rounded,
    'warning' => Icons.warning_amber_rounded,
    _ => Icons.notifications_rounded,
  };

  String _relativeTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp.toLocal());
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    final local = timestamp.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
