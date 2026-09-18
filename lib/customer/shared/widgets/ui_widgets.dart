part of '../../app.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, required this.size, this.centered = false});
  final double size;
  final bool centered;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return RichText(
      textAlign: centered ? TextAlign.center : TextAlign.start,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
        children: [
          TextSpan(
            text: 'Tala',
            style: TextStyle(color: palette.brand),
          ),
          const TextSpan(
            text: 'Delivery',
            style: TextStyle(color: sky),
          ),
        ],
      ),
    );
  }
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (icon != null) ...[const SizedBox(width: 9), Icon(icon, size: 20)],
        ],
      ),
    ),
  );
}

class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
    color: appPaletteOf(context).surface,
    padding: EdgeInsets.fromLTRB(
      20,
      13,
      20,
      13 + MediaQuery.paddingOf(context).bottom,
    ),
    child: FilledButton(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: child,
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.action,
    this.onTap,
  });
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ],
  );
}

class QuantityControl extends StatelessWidget {
  const QuantityControl({
    super.key,
    required this.value,
    this.onMinus,
    this.onPlus,
  });
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded, color: sky),
          ),
        ],
      ),
    );
  }
}

class CartItem extends StatelessWidget {
  const CartItem({
    super.key,
    required this.name,
    required this.price,
    required this.quantity,
    required this.icon,
    required this.onMinus,
    required this.onPlus,
  });
  final String name;
  final double price;
  final int quantity;
  final IconData icon;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return InfoCard(
      child: Row(
        children: [
          StoreArtwork(icon: icon, color: sky, height: 58, width: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${peso(price)} × $quantity',
                  style: TextStyle(color: palette.quiet, fontSize: 12),
                ),
                const SizedBox(height: 7),
                QuantityControl(
                  value: quantity,
                  onMinus: onMinus,
                  onPlus: onPlus,
                ),
              ],
            ),
          ),
          Text(
            peso(price * quantity),
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    this.delivery,
    this.total,
  });
  final double subtotal;
  final double? delivery;
  final double? total;
  @override
  Widget build(BuildContext context) => InfoCard(
    child: Column(
      children: [
        SummaryLine(label: 'Subtotal', value: peso(subtotal)),
        SummaryLine(
          label: 'Delivery fee',
          value: delivery == null ? 'Calculated by API' : peso(delivery!),
        ),
        SummaryLine(
          label: 'Total',
          value: total == null
              ? peso(subtotal + (delivery ?? 0))
              : peso(total!),
          bold: true,
          last: true,
        ),
      ],
    ),
  );
}

class SummaryLine extends StatelessWidget {
  const SummaryLine({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.last = false,
  });
  final String label;
  final String value;
  final bool bold;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: bold ? palette.text : palette.quiet,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: palette.text,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                fontSize: bold ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutTitle extends StatelessWidget {
  const CheckoutTitle({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: sky, size: 21),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class TrackingHero extends StatelessWidget {
  const TrackingHero({super.key, required this.stage});
  final OrderStage stage;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final done = stage == OrderStage.delivered;
    final cancelled = stage == OrderStage.cancelled;
    final accent = cancelled
        ? danger
        : done
        ? success
        : sky;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: cancelled
            ? palette.dangerFill
            : done
            ? palette.successFill
            : palette.softBlue,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: .16), blurRadius: 15),
              ],
            ),
            child: Icon(
              cancelled
                  ? Icons.close_rounded
                  : done
                  ? Icons.check_rounded
                  : stage == OrderStage.findingRider
                  ? Icons.radar_rounded
                  : stage.index >= OrderStage.assigned.index
                  ? Icons.delivery_dining_rounded
                  : Icons.inventory_2_rounded,
              color: accent,
              size: 33,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            stage.title,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(stage.description, textAlign: TextAlign.center),
          if (stage == OrderStage.findingRider) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 5,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              backgroundColor: palette.surface,
            ),
          ],
        ],
      ),
    );
  }
}

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.label,
    required this.complete,
    required this.active,
    required this.last,
  });
  final String label;
  final bool complete;
  final bool active;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: complete || active ? sky : palette.inactiveStep,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.surface, width: 4),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: complete ? sky : palette.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Text(
                label,
                style: TextStyle(
                  color: complete || active ? palette.text : palette.quiet,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({
    super.key,
    required this.store,
    required this.id,
    required this.total,
    required this.status,
    required this.color,
    required this.date,
    required this.onTap,
  });
  final String store;
  final String id;
  final String total;
  final String status;
  final Color color;
  final String date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  StatusPill(label: status, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$id\n$date',
                      style: TextStyle(
                        color: palette.quiet,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  Text(
                    total,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.chevron_right_rounded, color: sky),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.label,
    required this.address,
    required this.selected,
    required this.onDefault,
    required this.onEdit,
    this.onDelete,
  });
  final String label;
  final String address;
  final bool selected;
  final VoidCallback onDefault;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return InfoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            label == 'Home' ? Icons.home_rounded : Icons.work_rounded,
            color: sky,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const StatusPill(label: 'Default', color: success),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(address, style: TextStyle(color: palette.quiet)),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 6,
                  children: [
                    if (!selected)
                      TextButton(
                        onPressed: onDefault,
                        child: const Text('Set default'),
                      ),
                    TextButton(onPressed: onEdit, child: const Text('Edit')),
                    if (onDelete != null)
                      TextButton(
                        onPressed: onDelete,
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: danger),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.messageText,
    required this.time,
    required this.onTap,
    this.isRead = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String messageText;
  final String time;
  final VoidCallback onTap;
  final bool isRead;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Material(
      color: isRead ? palette.surface : palette.unreadFill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      messageText,
                      style: TextStyle(color: palette.quiet, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      time,
                      style: const TextStyle(
                        color: sky,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: destructive ? danger : sky),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: destructive ? danger : palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: destructive ? danger : palette.quiet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
