part of '../../app.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar(
      'Notifications',
      actions: [
        TextButton(
          onPressed: () =>
              message(context, 'All notifications marked as read.'),
          child: const Text('Mark read'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        NotificationTile(
          icon: Icons.delivery_dining_rounded,
          color: sky,
          title: 'Rider assigned',
          messageText: 'Juan Dela Cruz is heading to ABC Mini Mart.',
          time: '2 min ago',
        ),
        SizedBox(height: 10),
        NotificationTile(
          icon: Icons.inventory_2_outlined,
          color: warning,
          title: 'Order ready',
          messageText: 'Your order is packed and ready for pickup.',
          time: '8 min ago',
        ),
        SizedBox(height: 10),
        NotificationTile(
          icon: Icons.storefront_rounded,
          color: success,
          title: 'Order confirmed',
          messageText: 'ABC Mini Mart accepted order #TD-100001.',
          time: '15 min ago',
        ),
      ],
    ),
  );
}
