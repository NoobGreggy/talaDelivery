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
          fontFamily: 'Arial',
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
  final VoidCallback onTap;
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

class CategoryButton extends StatefulWidget {
  const CategoryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  State<CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<CategoryButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => pressed = true),
    onTapCancel: () => setState(() => pressed = false),
    onTapUp: (_) {
      setState(() => pressed = false);
      widget.onTap();
    },
    child: AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: pressed ? .94 : 1,
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Center(
              child: Icon(widget.icon, color: widget.color, size: 27),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: appPaletteOf(context).text,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class StoreArtwork extends StatelessWidget {
  const StoreArtwork({
    super.key,
    required this.icon,
    required this.color,
    this.large = false,
    this.height,
    this.width,
  });
  final IconData icon;
  final Color color;
  final bool large;
  final double? height;
  final double? width;
  @override
  Widget build(BuildContext context) => Container(
    height: height ?? (large ? 220 : 92),
    width: width,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(large ? 0 : 17),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: color, size: large ? 82 : 38),
        if (large) ...[
          Positioned(
            right: 24,
            top: 28,
            child: Icon(
              Icons.auto_awesome,
              color: color.withValues(alpha: .45),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 32,
            child: Icon(
              Icons.circle,
              color: color.withValues(alpha: .18),
              size: 40,
            ),
          ),
        ],
      ],
    ),
  );
}

class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store, required this.onTap});
  final StoreData store;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: StoreArtwork(icon: store.icon, color: store.color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: TextStyle(
                              color: palette.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: store.open ? 'Open' : 'Closed',
                          color: store.open ? success : danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      store.address ?? store.description ?? 'Store details',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.quiet, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Metric(
                      icon: Icons.schedule_rounded,
                      value: store.openingTime == null
                          ? 'Hours not provided'
                          : '${store.openingTime} – ${store.closingTime ?? ''}',
                      color: palette.quiet,
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

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: appPaletteOf(context).quiet,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.product,
    required this.onOpen,
    this.onAdd,
  });
  final ProductData product;
  final VoidCallback onOpen;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Hero(
                tag: product.name,
                child: SizedBox(
                  width: 76,
                  child: StoreArtwork(
                    icon: product.icon,
                    color: product.color,
                    height: 76,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.description ?? 'No description provided.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.quiet, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      peso(product.price),
                      style: const TextStyle(
                        color: sky,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 42),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: onAdd == null
                    ? const Icon(Icons.block_rounded, size: 18)
                    : const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            child: Text(
              label,
              style: TextStyle(
                color: bold ? palette.text : palette.quiet,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.text,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: bold ? 18 : 14,
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

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.infoFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: sky, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.quiet, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionLabel,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, color: appPaletteOf(context).emptyIcon, size: 58),
        const SizedBox(height: 15),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center),
        if (action != null && actionLabel != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: action, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

String apiErrorMessage(Object? error) => switch (error) {
  CustomerApiException apiError => apiError.message,
  FormatException _ => 'The server returned data in an unexpected format.',
  _ => 'Unable to reach TalaDelivery. Please try again.',
};

class ApiErrorState extends StatelessWidget {
  const ApiErrorState({
    super.key,
    required this.messageText,
    required this.onRetry,
  });

  final String messageText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: danger, size: 54),
          const SizedBox(height: 14),
          Text(
            messageText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

enum ToastKind { success, info, warning, error }

Future<bool> confirmAction(
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
        color: destructive ? danger : sky,
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
              ? FilledButton.styleFrom(backgroundColor: danger)
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

PreferredSizeWidget simpleBar(String title, {List<Widget>? actions}) =>
    AppBar(title: Text(title), actions: actions);
Route<T> fade<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (context, animation, secondaryAnimation) =>
      FadeTransition(opacity: animation, child: page),
  transitionDuration: const Duration(milliseconds: 320),
);
Route<T> slide<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (context, animation, secondaryAnimation) => SlideTransition(
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: page,
  ),
  transitionDuration: const Duration(milliseconds: 330),
);
void message(
  BuildContext context,
  String value, {
  ToastKind kind = ToastKind.info,
}) {
  final palette = appPaletteOf(context);
  final color = switch (kind) {
    ToastKind.success => success,
    ToastKind.info => palette.brand,
    ToastKind.warning => warning,
    ToastKind.error => danger,
  };
  final icon = switch (kind) {
    ToastKind.success => Icons.check_circle_rounded,
    ToastKind.info => Icons.info_rounded,
    ToastKind.warning => Icons.warning_amber_rounded,
    ToastKind.error => Icons.error_rounded,
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
                  value,
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
