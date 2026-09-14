part of '../../app.dart';

class StoreListingPage extends StatefulWidget {
  const StoreListingPage({super.key, this.initialFilter = 0});
  final int initialFilter;
  @override
  State<StoreListingPage> createState() => _StoreListingPageState();
}

class _StoreListingPageState extends State<StoreListingPage> {
  late int filter;
  bool statePreview = false;
  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['All', 'Food', 'Grocery', 'Pharmacy', 'Other'];
    return Scaffold(
      appBar: simpleBar(
        'Stores',
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, slide(const CartPage())),
            icon: Badge.count(
              count: 3,
              child: Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search stores or products',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) {},
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ChoiceChip(
                label: Text(labels[index]),
                selected: filter == index,
                onSelected: (_) => setState(() => filter = index),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '${filter == 0 ? stores.length : 2} stores nearby',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => statePreview = !statePreview),
                icon: const Icon(Icons.layers_outlined, size: 18),
                label: const Text('UI states'),
              ),
            ],
          ),
          if (statePreview) ...[
            const SizedBox(height: 8),
            const StatePreviewRow(),
            const SizedBox(height: 16),
          ],
          ...stores
              .where((store) => filter == 0 || store.categoryIndex == filter)
              .map(
                (store) => Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: StoreCard(
                    store: store,
                    onTap: store.open
                        ? () => Navigator.push(
                            context,
                            slide(StoreDetailPage(store: store)),
                          )
                        : () => message(
                            context,
                            'This store is currently closed.',
                          ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class StoreDetailPage extends StatefulWidget {
  const StoreDetailPage({super.key, required this.store});
  final StoreData store;
  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  int cartCount = 0;
  int category = 0;
  Future<void> openProduct(ProductData product) async {
    final quantity = await Navigator.push<int>(
      context,
      slide(ProductDetailPage(product: product)),
    );
    if (quantity != null && mounted) {
      setState(() => cartCount += quantity);
      message(
        context,
        '$quantity ${product.name} added to your cart.',
        kind: ToastKind.success,
      );
    }
  }

  void addProduct(ProductData product) {
    setState(() => cartCount++);
    message(
      context,
      '${product.name} added to your cart.',
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: dark,
          actions: [
            IconButton.filledTonal(
              onPressed: () => Navigator.push(context, slide(const CartPage())),
              icon: Badge.count(
                count: cartCount,
                isLabelVisible: cartCount > 0,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: StoreArtwork(
              icon: widget.store.icon,
              color: widget.store.color,
              large: true,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.store.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const StatusPill(label: 'Open', color: success),
                  ],
                ),
                const SizedBox(height: 7),
                Text(widget.store.description),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Metric(
                      icon: Icons.star_rounded,
                      value: widget.store.rating,
                      color: warning,
                    ),
                    const SizedBox(width: 16),
                    Metric(
                      icon: Icons.delivery_dining_rounded,
                      value: '₱${widget.store.fee}',
                      color: sky,
                    ),
                    const SizedBox(width: 16),
                    Metric(
                      icon: Icons.schedule_rounded,
                      value: widget.store.eta,
                      color: quiet,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 41,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: const [
                      'Popular',
                      'Meals',
                      'Drinks',
                      'Essentials',
                    ].length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => ChoiceChip(
                      label: Text(
                        const [
                          'Popular',
                          'Meals',
                          'Drinks',
                          'Essentials',
                        ][index],
                      ),
                      selected: category == index,
                      onSelected: (_) => setState(() => category = index),
                    ),
                  ),
                ),
                const SizedBox(height: 23),
                const SectionHeading(title: 'Products'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          sliver: SliverList.separated(
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => ProductRow(
              product: products[index],
              onOpen: () => openProduct(products[index]),
              onAdd: products[index].available
                  ? () => addProduct(products[index])
                  : null,
            ),
          ),
        ),
      ],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    floatingActionButton: cartCount > 0
        ? SizedBox(
            width: MediaQuery.sizeOf(context).width - 40,
            child: PrimaryAction(
              label:
                  'View cart • $cartCount ${cartCount == 1 ? 'item' : 'items'}',
              icon: Icons.shopping_cart_rounded,
              onTap: () => Navigator.push(context, slide(const CartPage())),
            ),
          )
        : null,
  );
}
