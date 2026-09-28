part of '../../app.dart';

String notificationTime(DateTime? date) {
  if (date == null) return '';
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} hr ago';
  return shortDate(date);
}

String notificationDayLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference <= 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return shortDate(date);
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<List<CustomerNotification>>? future;
  CustomerRealtimeController? realtime;
  int seenNotificationVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRealtime = CustomerDependencyScope.of(context).realtime;
    if (realtime != nextRealtime) {
      realtime?.removeListener(onNotificationEvent);
      realtime = nextRealtime;
      seenNotificationVersion = nextRealtime.notificationVersion;
      nextRealtime.addListener(onNotificationEvent);
    }
    future ??= CustomerDependencyScope.of(context).notificationRepository
        .list();
  }

  @override
  void dispose() {
    realtime?.removeListener(onNotificationEvent);
    super.dispose();
  }

  void onNotificationEvent() {
    if (realtime!.notificationVersion == seenNotificationVersion) return;
    seenNotificationVersion = realtime!.notificationVersion;
    reload();
  }

  void reload() => setState(() {
    future = CustomerDependencyScope.of(context).notificationRepository.list();
  });

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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: FutureBuilder<List<CustomerNotification>>(
        future: future,
        builder: (context, snapshot) {
          final raw = snapshot.data ?? const <CustomerNotification>[];
          final notifications = [...raw]..sort(
            (a, b) => (b.createdAt ?? DateTime(1970))
                .compareTo(a.createdAt ?? DateTime(1970)),
          );
          final unread = notifications.where((item) => !item.isRead).length;
          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await future;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _NotificationsHero(
                    unread: unread,
                    onBack: () => Navigator.maybePop(context),
                  ),
                ),
                if (snapshot.connectionState != ConnectionState.done) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ] else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: ApiErrorState(
                        messageText: apiErrorMessage(snapshot.error),
                        onRetry: reload,
                      ),
                    ),
                  )
                else if (notifications.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications',
                      subtitle: 'Order and delivery updates will appear here.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 40),
                    sliver: SliverList.list(
                      children: _notificationGroups(context, notifications),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );

  /// Day headings plus their tiles, mirroring the dashboard's section rows.
  List<Widget> _notificationGroups(
    BuildContext context,
    List<CustomerNotification> notifications,
  ) {
    final palette = appPaletteOf(context);
    final grouped = <String, List<CustomerNotification>>{};
    for (final notification in notifications) {
      final label = notification.createdAt == null
          ? 'Earlier'
          : notificationDayLabel(notification.createdAt!);
      grouped.putIfAbsent(label, () => []).add(notification);
    }
    return [
      for (final entry in grouped.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: palette.softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${entry.value.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var index = 0; index < entry.value.length; index++) ...[
                if (index != 0) const SizedBox(height: 11),
                _buildTile(context, entry.value[index]),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildTile(BuildContext context, CustomerNotification notification) {
    final quiet = appPaletteOf(context).quiet;
    final style = _notificationStyle(context, notification);
    return NotificationTile(
      icon: style.icon,
      color: notification.isRead ? quiet : style.color,
      title: notification.title,
      messageText: notification.messageText,
      time: notificationTime(notification.createdAt),
      isRead: notification.isRead,
      onTap: () => open(notification),
    );
  }
}

({IconData icon, Color color}) _notificationStyle(
  BuildContext context,
  CustomerNotification notification,
) {
  final palette = appPaletteOf(context);
  final type = notification.type.toLowerCase();
  if (type.contains('delivered') || type.contains('complete')) {
    return (icon: Icons.check_circle_rounded, color: success);
  }
  if (type.contains('assigned') ||
      type.contains('rider') ||
      type.contains('dispatch')) {
    return (icon: Icons.delivery_dining_rounded, color: sky);
  }
  if (type.contains('cancel')) {
    return (icon: Icons.cancel_rounded, color: danger);
  }
  if (type.contains('ready') || type.contains('prepare')) {
    return (icon: Icons.restaurant_rounded, color: palette.ratingStar);
  }
  if (type.contains('payment') || type.contains('paid')) {
    return (icon: Icons.payments_rounded, color: success);
  }
  if (notification.orderId != null) {
    return (icon: Icons.receipt_long_outlined, color: sky);
  }
  return (
    icon: Icons.notifications_outlined,
    color: palette.ratingStar,
  );
}

/// Matches the dashboard hero so opened notifications feel part of the home
/// experience instead of a separate utility page.
class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({required this.unread, required this.onBack});

  final int unread;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => TalaDuskSky(
    animate: !MediaQuery.disableAnimationsOf(context),
    shootingStar: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        46,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: .25)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unread == 0
                      ? 'You are all caught up'
                      : '$unread unread update${unread == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .7),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Notifications, $unread unread',
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: .25)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        key: const Key('notifications-unread-badge'),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: appPaletteOf(context).urgent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: appPaletteOf(context).duskDeep,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
