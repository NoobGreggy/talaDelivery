part of '../../app.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, required this.size, this.centered = false});
  final double size;
  final bool centered;
  @override
  Widget build(BuildContext context) => RichText(
    textAlign: centered ? TextAlign.center : TextAlign.start,
    text: TextSpan(
      style: TextStyle(
        fontFamily: 'Arial',
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      ),
      children: const [
        TextSpan(
          text: 'Tala',
          style: TextStyle(color: dark),
        ),
        TextSpan(
          text: 'Delivery',
          style: TextStyle(color: sky),
        ),
      ],
    ),
  );
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
    color: Colors.white,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEBF0F5)),
    ),
    child: child,
  );
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
            style: const TextStyle(
              color: text,
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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
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
                          style: const TextStyle(
                            color: text,
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
                    store.categoryIndex == 1
                        ? 'Food'
                        : store.categoryIndex == 2
                        ? 'Grocery'
                        : store.categoryIndex == 3
                        ? 'Pharmacy'
                        : 'Other',
                    style: const TextStyle(color: quiet, fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Metric(
                        icon: Icons.star_rounded,
                        value: store.rating,
                        color: warning,
                      ),
                      Metric(
                        icon: Icons.delivery_dining_rounded,
                        value: '₱${store.fee}',
                        color: sky,
                      ),
                      Metric(
                        icon: Icons.schedule_rounded,
                        value: store.eta,
                        color: quiet,
                      ),
                    ],
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
      Text(
        value,
        style: const TextStyle(
          color: quiet,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
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
                    style: const TextStyle(
                      color: text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: quiet, fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '₱${product.price}',
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(color: text, fontWeight: FontWeight.w900),
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
  final int price;
  final int quantity;
  final IconData icon;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  @override
  Widget build(BuildContext context) => InfoCard(
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
                style: const TextStyle(
                  color: text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '₱$price × $quantity',
                style: const TextStyle(color: quiet, fontSize: 12),
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
          '₱${price * quantity}',
          style: const TextStyle(color: text, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    required this.delivery,
  });
  final int subtotal;
  final int delivery;
  @override
  Widget build(BuildContext context) => InfoCard(
    child: Column(
      children: [
        SummaryLine(label: 'Subtotal', value: '₱$subtotal'),
        SummaryLine(label: 'Delivery fee', value: '₱$delivery'),
        SummaryLine(
          label: 'Total',
          value: '₱${subtotal + delivery}',
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 13),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: bold ? text : quiet,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: text,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    ),
  );
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
    final done = stage == OrderStage.delivered;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE7F8F0) : const Color(0xFFE7F4FF),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (done ? success : sky).withValues(alpha: .16),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Icon(
              done
                  ? Icons.check_rounded
                  : stage == OrderStage.findingRider
                  ? Icons.radar_rounded
                  : stage.index >= OrderStage.assigned.index
                  ? Icons.delivery_dining_rounded
                  : Icons.inventory_2_rounded,
              color: done ? success : sky,
              size: 33,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            stage.title,
            style: const TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(stage.description, textAlign: TextAlign.center),
          if (stage == OrderStage.findingRider) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(
              minHeight: 5,
              borderRadius: BorderRadius.all(Radius.circular(6)),
              backgroundColor: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

class RiderCard extends StatelessWidget {
  const RiderCard({super.key, required this.stage});
  final OrderStage stage;
  @override
  Widget build(BuildContext context) => InfoCard(
    child: Row(
      children: [
        const CircleAvatar(
          radius: 27,
          backgroundColor: Color(0xFFE1F0FD),
          child: Text(
            'JD',
            style: TextStyle(color: sky, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR RIDER',
                style: TextStyle(
                  color: sky,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Text(
                'Juan Dela Cruz',
                style: TextStyle(color: text, fontWeight: FontWeight.w900),
              ),
              Text(
                stage == OrderStage.outForDelivery
                    ? 'Motorcycle • On the way'
                    : 'Motorcycle • Heading to store',
                style: const TextStyle(color: quiet, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => message(context, 'Calling your rider…'),
          icon: const Icon(Icons.call_rounded),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => IntrinsicHeight(
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
                  color: complete || active ? sky : const Color(0xFFCCD7E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: complete ? sky : line),
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
                color: complete || active ? text : quiet,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
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
                    style: const TextStyle(
                      color: text,
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
                    style: const TextStyle(
                      color: quiet,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    color: text,
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
  Widget build(BuildContext context) => InfoCard(
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
                    style: const TextStyle(
                      color: text,
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
              Text(address, style: const TextStyle(color: quiet)),
              const SizedBox(height: 11),
              Wrap(
                spacing: 6,
                children: [
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

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.messageText,
    required this.time,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String messageText;
  final String time;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, slide(const OrderTrackingPage())),
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
                    style: const TextStyle(
                      color: text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    messageText,
                    style: const TextStyle(color: quiet, fontSize: 13),
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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
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
                  color: destructive ? danger : text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: destructive ? danger : quiet,
            ),
          ],
        ),
      ),
    ),
  );
}

class SavedAddressPicker extends StatelessWidget {
  const SavedAddressPicker({super.key});
  @override
  Widget build(BuildContext context) => const InfoCard(
    child: Row(
      children: [
        Icon(Icons.home_rounded, color: sky),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Home',
                style: TextStyle(color: text, fontWeight: FontWeight.w900),
              ),
              Text(
                '123 Example Street, Cabanatuan City',
                style: TextStyle(color: quiet, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: success),
      ],
    ),
  );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F4FF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: sky, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: quiet, fontSize: 12)),
        ),
      ],
    ),
  );
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
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFFB8C7D5), size: 58),
        const SizedBox(height: 15),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}

class StatePreviewRow extends StatelessWidget {
  const StatePreviewRow({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: const Row(
      children: [
        Icon(Icons.hourglass_empty_rounded, color: sky),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Loading  •  Empty  •  Error  •  Retry',
            style: TextStyle(color: quiet, fontWeight: FontWeight.w700),
          ),
        ),
        Icon(Icons.refresh_rounded, color: sky),
      ],
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

Future<void> showCancelDialog(BuildContext context) async {
  final confirmed = await confirmAction(
    context,
    title: 'Cancel order?',
    body: 'You can cancel while the order is still pending. This action cannot be undone.',
    confirmLabel: 'Cancel order',
    destructive: true,
  );
  if (context.mounted && confirmed) {
    message(context, 'Order cancelled successfully.', kind: ToastKind.success);
  }
}

PreferredSizeWidget simpleBar(String title, {List<Widget>? actions}) => AppBar(
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.white,
  title: Text(
    title,
    style: const TextStyle(
      color: text,
      fontWeight: FontWeight.w900,
      fontSize: 18,
    ),
  ),
  actions: actions,
);
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
  final color = switch (kind) {
    ToastKind.success => success,
    ToastKind.info => dark,
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
