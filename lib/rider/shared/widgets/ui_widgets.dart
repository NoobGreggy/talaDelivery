part of '../../app.dart';

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
  Widget build(BuildContext context) => RichText(
    textAlign: centered ? TextAlign.center : TextAlign.start,
    text: TextSpan(
      style: TextStyle(
        fontFamily: 'Arial',
        fontSize: compact ? 22 : 35,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      ),
      children: const [
        TextSpan(
          text: 'Tala',
          style: TextStyle(color: navy),
        ),
        TextSpan(
          text: 'Delivery',
          style: TextStyle(color: blue),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ),
    onPressed:
        onPressed ??
        () => Navigator.of(context).popUntil((route) => route.isFirst),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (icon != null) ...[
            const SizedBox(width: 10),
            Icon(icon, size: 20),
          ],
        ],
      ),
    ),
  );
}

class SkyBackdrop extends StatelessWidget {
  const SkyBackdrop({super.key});
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFE8F5FF), Color(0xFFCFEAFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: CustomPaint(painter: SkylinePainter()),
  );
}

class SkylinePainter extends CustomPainter {
  const SkylinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB7DDFA).withValues(alpha: .5);
    final path = Path()..moveTo(0, size.height * .78);
    for (var x = 0.0; x < size.width; x += 48) {
      final height = 25 + (x.toInt() % 90);
      path
        ..lineTo(x, size.height * .78)
        ..lineTo(x, size.height * .78 - height)
        ..lineTo(x + 32, size.height * .78 - height)
        ..lineTo(x + 32, size.height * .78);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .52, size.height * 1.05),
        width: size.width * 1.5,
        height: size.height * .62,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 52,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RouteMapPainter extends CustomPainter {
  const RouteMapPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8F2FA),
    );
    final roads = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    for (var i = -1; i < 6; i++) {
      canvas.drawLine(
        Offset(i * 80.0, 0),
        Offset(i * 80.0 + 130, size.height),
        roads,
      );
      canvas.drawLine(
        Offset(0, i * 48.0),
        Offset(size.width, i * 48.0 + 80),
        roads,
      );
    }
    final route = Path()
      ..moveTo(30, 170)
      ..cubicTo(90, 148, 70, 85, 150, 100)
      ..cubicTo(230, 115, 250, 45, size.width - 28, 42);
    canvas.drawPath(
      route,
      Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(30, 170), 9, Paint()..color = blue);
    canvas.drawCircle(Offset(size.width - 28, 42), 10, Paint()..color = navy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RiderMapPin extends StatelessWidget {
  const RiderMapPin({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: navy.withValues(alpha: .2), blurRadius: 16)],
    ),
    padding: const EdgeInsets.all(9),
    child: const RiderLogo(size: 42),
  );
}

class FeaturePill extends StatelessWidget {
  const FeaturePill({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: blue),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
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
      color: color.withValues(alpha: .12),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon: icon, color: iconColor),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        Text(label, style: const TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
}

class EarningsCard extends StatelessWidget {
  const EarningsCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        IconTile(icon: Icons.account_balance_wallet_rounded, color: orange),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TODAY’S EARNINGS',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '₱540',
                style: TextStyle(
                  color: ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.trending_up_rounded, color: green),
      ],
    ),
  );
}

class DeliveryRow extends StatelessWidget {
  const DeliveryRow({
    super.key,
    required this.store,
    required this.id,
    required this.time,
    required this.fee,
  });
  final String store;
  final String id;
  final String time;
  final String fee;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
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
                store,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '$id • $time',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fee,
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const Text(
              'Delivered',
              style: TextStyle(
                color: green,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class RouteCard extends StatelessWidget {
  const RouteCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      children: [
        RouteStop(
          color: blue,
          label: 'PICKUP',
          title: 'ABC Mini Mart',
          subtitle: '2.3 km away',
        ),
        Padding(
          padding: EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 28,
              child: VerticalDivider(
                color: Color(0xFFB6CBE0),
                thickness: 2,
                width: 2,
              ),
            ),
          ),
        ),
        RouteStop(
          color: navy,
          label: 'DROP-OFF',
          title: 'Juan Dela Cruz',
          subtitle: '4.8 km from pickup',
        ),
      ],
    ),
  );
}

class RouteStop extends StatelessWidget {
  const RouteStop({
    super.key,
    required this.color,
    required this.label,
    required this.title,
    required this.subtitle,
  });
  final Color color;
  final String label;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .25), blurRadius: 5),
          ],
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Icon(icon, color: blue, size: 22),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 10)),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.status, required this.stage});
  final String status;
  final int stage;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F4FF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const IconTile(icon: Icons.delivery_dining_rounded, color: blue),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP $stage OF 4',
                style: const TextStyle(
                  color: blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                status,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.circle, color: green, size: 11),
      ],
    ),
  );
}

class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.address,
    required this.icon,
    required this.trailing,
  });
  final String eyebrow;
  final String title;
  final String address;
  final IconData icon;
  final String trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon: icon, color: blue),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(address, style: const TextStyle(color: muted, fontSize: 13)),
            ],
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class SecondaryAction extends StatelessWidget {
  const SecondaryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      side: const BorderSide(color: Color(0xFFBCD8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      foregroundColor: blue,
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 19),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

class PickupCodeCard extends StatelessWidget {
  const PickupCodeCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        Icon(Icons.pin_outlined, color: orange),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PICKUP CODE',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '8392',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 25,
                ),
              ),
            ],
          ),
        ),
        Text('Show to store', style: TextStyle(color: muted, fontSize: 12)),
      ],
    ),
  );
}

class CodCard extends StatelessWidget {
  const CodCard({super.key, required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool?> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFEFFAF5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFC8EEDD)),
    ),
    child: Row(
      children: [
        const IconTile(icon: Icons.payments_rounded, color: green),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CASH TO COLLECT',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '₱399',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 25,
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Checkbox(value: checked, onChanged: onChanged, activeColor: green),
            const Text(
              'Received',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

class OrderNotesCard extends StatelessWidget {
  const OrderNotesCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.sticky_note_2_outlined, color: muted),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order note',
                style: TextStyle(color: ink, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'Please handle with care. Call upon arrival.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CompletionStat extends StatelessWidget {
  const CompletionStat({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    ],
  );
}

class LightStat extends StatelessWidget {
  const LightStat({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFFD9EEFF), fontSize: 12),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    ],
  );
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
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.destructive = false,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final bool destructive;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap:
          onTap ??
          () =>
              showMessage(context, '$title is ready for backend integration.'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: destructive ? Colors.redAccent : blue),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: destructive ? Colors.redAccent : ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: destructive ? Colors.redAccent : muted,
            ),
          ],
        ),
      ),
    ),
  );
}

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (context, animation, secondaryAnimation) =>
      FadeTransition(opacity: animation, child: page),
  transitionDuration: const Duration(milliseconds: 350),
);
Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (context, animation, secondaryAnimation) => SlideTransition(
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: page,
  ),
  transitionDuration: const Duration(milliseconds: 350),
);

enum RiderToastKind { success, info, warning, error }

Future<bool> confirmRiderAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
        color: destructive ? Colors.redAccent : blue,
        size: 34,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(body, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(
  BuildContext context,
  String message, {
  RiderToastKind kind = RiderToastKind.info,
}) {
  final color = switch (kind) {
    RiderToastKind.success => green,
    RiderToastKind.info => navy,
    RiderToastKind.warning => orange,
    RiderToastKind.error => Colors.redAccent,
  };
  final icon = switch (kind) {
    RiderToastKind.success => Icons.check_circle_rounded,
    RiderToastKind.info => Icons.info_rounded,
    RiderToastKind.warning => Icons.warning_amber_rounded,
    RiderToastKind.error => Icons.error_rounded,
  };
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          MediaQuery.sizeOf(context).height * .72,
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 21),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
