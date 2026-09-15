part of '../../app.dart';

String riderMoney(num value) =>
    '₱${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';

String riderDate(DateTime? value) {
  if (value == null) return '';
  final date = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class RiderLogo extends StatelessWidget {
  const RiderLogo({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/tala_rider.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.centered = false, this.compact = false});
  final bool centered;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return RichText(
      textAlign: centered ? TextAlign.center : TextAlign.start,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Arial',
          fontSize: compact ? 22 : 35,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
        children: [
          TextSpan(
            text: 'Tala',
            style: TextStyle(color: palette.text),
          ),
          const TextSpan(
            text: 'Delivery',
            style: TextStyle(color: blue),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    onPressed: onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

class SkyBackdrop extends StatelessWidget {
  const SkyBackdrop({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.splashStart, palette.splashMid, palette.splashEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
  });
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(icon, color: color, size: size * .52),
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: iconColor),
          const SizedBox(height: 14),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class EarningsCard extends StatelessWidget {
  const EarningsCard({super.key, required this.amount});
  final double amount;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.softOrange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const IconTile(
            icon: Icons.account_balance_wallet_rounded,
            color: orange,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY’S EARNINGS',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  riderMoney(amount),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryRow extends StatelessWidget {
  const DeliveryRow({super.key, required this.delivery});
  final RiderDelivery delivery;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const IconTile(icon: Icons.check_rounded, color: green),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.store?.name ?? 'Delivery',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${delivery.displayNumber} • ${riderDate(delivery.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            riderMoney(delivery.deliveryFee),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class RiderNoticeCard extends StatelessWidget {
  const RiderNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Material(
      color: palette.softBlue,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              IconTile(icon: icon, color: blue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(message, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: blue),
            ],
          ),
        ),
      ),
    );
  }
}

class RiderEmptyState extends StatelessWidget {
  const RiderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: blue),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.delivery});
  final RiderDelivery delivery;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _RouteStop(
            icon: Icons.storefront,
            label: 'PICKUP',
            title: delivery.store?.name ?? 'Store',
            subtitle: delivery.pickupAddress,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          _RouteStop(
            icon: Icons.home_rounded,
            label: 'DROP-OFF',
            title: delivery.order?.customerName ?? 'Customer',
            subtitle: delivery.deliveryAddress,
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconTile(icon: icon, color: blue),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: blue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              subtitle.isEmpty ? 'Address unavailable' : subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class MiniInfo extends StatelessWidget {
  const MiniInfo({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, color: blue),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.destructive = false,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool destructive;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final palette = riderPaletteOf(context);
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : palette.text;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(17),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class ProfileDetail extends StatelessWidget {
  const ProfileDetail({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: blue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

enum RiderToastKind { success, warning }

void showMessage(BuildContext context, String message, {RiderToastKind? kind}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmRiderAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;
