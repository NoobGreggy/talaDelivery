part of '../../app.dart';

String notificationTime(DateTime? date) {
  if (date == null) return '';
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} hr ago';
  return shortDate(date);
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<List<CustomerNotification>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= CustomerDependencyScope.of(context).notificationRepository
        .list();
  }

  void reload() => setState(
    () =>
        future = CustomerDependencyScope.of(context).notificationRepository
            .list(),
  );

  Future<void> open(CustomerNotification notification) async {
    try {
      if (!notification.isRead) {
        await CustomerDependencyScope.of(context).notificationRepository
            .markRead(notification.id);
      }
      if (!mounted) return;
      if (notification.orderId != null) {
        await Navigator.pushNamed(
          context,
          CustomerRoutes.orderTracking,
          arguments: notification.orderId,
        );
      }
      if (mounted) reload();
    } on CustomerApiException catch (error) {
      if (mounted) message(context, error.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar('Notifications'),
    body: FutureBuilder<List<CustomerNotification>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ApiErrorState(
            messageText: apiErrorMessage(snapshot.error),
            onRetry: reload,
          );
        }
        final notifications = snapshot.data ?? const [];
        if (notifications.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications',
            subtitle: 'Order and delivery updates will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await future;
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(
                icon: notification.type.startsWith('order')
                    ? Icons.receipt_long_outlined
                    : Icons.notifications_outlined,
                color: notification.isRead ? appPaletteOf(context).quiet : sky,
                title: notification.title,
                messageText: notification.messageText,
                time: notificationTime(notification.createdAt),
                isRead: notification.isRead,
                onTap: () => open(notification),
              );
            },
          ),
        );
      },
    ),
  );
}
