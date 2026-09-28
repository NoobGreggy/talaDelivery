part of '../../app.dart';

class StoreListingPage extends StatefulWidget {
  const StoreListingPage({
    super.key,
    this.initialFilter = 0,
    this.initialSearch = '',
  });

  final int initialFilter;
  final String initialSearch;

  @override
  State<StoreListingPage> createState() => _StoreListingPageState();
}

class _StoreListingPageState extends State<StoreListingPage> {
  late final TextEditingController searchController;
  CustomerCatalogRepository? repository;
  Future<List<StoreData>>? future;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.initialSearch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository ??= CustomerDependencyScope.of(context).catalogRepository;
    future ??= repository!.listStores(search: searchController.text);
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void search(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        future = repository!.listStores(search: value);
      });
    });
  }

  void reload() => setState(() {
    future = repository!.listStores(search: searchController.text);
  });

  @override
  Widget build(BuildContext context) {
    final cart = CustomerDependencyScope.of(context).cartController;
    return Scaffold(
      appBar: simpleBar(
        'Stores',
        actions: [
          ListenableBuilder(
            listenable: cart,
            builder: (context, _) => IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, CustomerRoutes.cart),
              icon: Badge.count(
                count: cart.itemCount,
                isLabelVisible: cart.itemCount > 0,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: TextField(
              key: const Key('store-search'),
              controller: searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'Search stores',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: search,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<StoreData>>(
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
                final stores = snapshot.data ?? const [];
                if (stores.isEmpty) {
                  return EmptyState(
                    icon: Icons.storefront_outlined,
                    title: searchController.text.isEmpty
                        ? 'No stores available'
                        : 'No matching stores',
                    subtitle: searchController.text.isEmpty
                        ? 'Active Laravel stores will appear here.'
                        : 'Try another search term.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    reload();
                    await future;
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                    itemCount: stores.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 13),
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      return StoreCard(
                        store: store,
                        onTap: () => Navigator.pushNamed(
                          context,
                          CustomerRoutes.storeDetails,
                          arguments: store,
                        ),
                      );
                    },
                  ),
                );
              },
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
  Future<StoreData>? future;
  int? categoryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= CustomerDependencyScope.of(context).catalogRepository
        .getStore(widget.store.id);
  }

  void reload() => setState(() {
    future = CustomerDependencyScope.of(context).catalogRepository
        .getStore(widget.store.id);
  });

  Future<void> addProduct(
    StoreData store,
    ProductData product, {
    int quantity = 1,
  }) async {
    final cart = CustomerDependencyScope.of(context).cartController;
    if (!cart.canAddFrom(store)) {
      final replace = await confirmAction(
        context,
        title: 'Start a new cart?',
        body: 'Your cart contains items from ${cart.store!.name}.',
        confirmLabel: 'Replace cart',
        destructive: true,
      );
      if (!replace || !mounted) return;
      cart.clear();
    }
    cart.add(store, product, quantity: quantity);
    if (mounted) {
      message(
        context,
        '$quantity ${product.name} added to your cart.',
        kind: ToastKind.success,
      );
    }
  }

  Future<void> openProduct(StoreData store, ProductData product) async {
    final quantity = await Navigator.pushNamed<int>(
      context,
      CustomerRoutes.productDetails,
      arguments: product,
    );
    if (quantity != null && mounted) {
      await addProduct(store, product, quantity: quantity);
    }
  }

  /// Groups the menu by category and orders both the categories and the items
  /// inside them alphabetically so the store reads like a proper menu.
  static List<_StoreMenuSection> _menuSections(StoreData store) {
    final pending = List<ProductData>.of(store.products);
    final categories = [...store.categories]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sections = <_StoreMenuSection>[];
    for (final category in categories) {
      final items = <ProductData>[];
      pending.removeWhere((product) {
        if (product.categoryId != category.id) return false;
        items.add(product);
        return true;
      });
      if (items.isEmpty) continue;
      items.sort(_byProductName);
      sections.add(
        _StoreMenuSection(
          categoryId: category.id,
          title: category.name,
          products: items,
        ),
      );
    }
    if (pending.isNotEmpty) {
      pending.sort(_byProductName);
      sections.add(
        _StoreMenuSection(
          categoryId: null,
          title: store.categories.isEmpty ? null : 'Other items',
          products: pending,
        ),
      );
    }
    return sections;
  }

  static int _byProductName(ProductData a, ProductData b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final cart = CustomerDependencyScope.of(context).cartController;
    return Scaffold(
      body: FutureBuilder<StoreData>(
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
          final store = snapshot.data!;
          final sections = _menuSections(store)
              .where(
                (section) =>
                    categoryId == null || section.categoryId == categoryId,
              )
              .toList(growable: false);
          final menuCount = sections.fold<int>(
            0,
            (total, section) => total + section.products.length,
          );
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: appPaletteOf(context).duskDeep,
                foregroundColor: Colors.white,
                actions: [
                  ListenableBuilder(
                    listenable: cart,
                    builder: (context, _) => IconButton.filledTonal(
                      onPressed: () =>
                          Navigator.pushNamed(context, CustomerRoutes.cart),
                      icon: Badge.count(
                        count: cart.itemCount,
                        isLabelVisible: cart.itemCount > 0,
                        child: const Icon(Icons.shopping_cart_outlined),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _StoreDetailHero(store: store),
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
                              store.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          StatusPill(
                            label: store.open ? 'Open' : 'Closed',
                            color: store.open ? success : danger,
                          ),
                        ],
                      ),
                      if (store.description != null) ...[
                        const SizedBox(height: 7),
                        Text(store.description!),
                      ],
                      if (store.address != null) ...[
                        const SizedBox(height: 10),
                        Metric(
                          icon: Icons.location_on_outlined,
                          value: store.address!,
                          color: sky,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _StoreMetricsCard(store: store),
                      if (store.categories.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        _StoreCategoryFilters(
                          categories: store.categories,
                          products: store.products,
                          selectedId: categoryId,
                          onSelected: (id) => setState(() => categoryId = id),
                        ),
                      ],
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Products',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Text(
                            '$menuCount ${menuCount == 1 ? 'item' : 'items'}',
                            style: TextStyle(
                              color: appPaletteOf(context).quiet,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (sections.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products available',
                    subtitle: 'Available products from Laravel appear here.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      for (var index = 0; index < sections.length; index++) ...[
                        if (sections[index].title != null)
                          SliverToBoxAdapter(
                            child: _StoreMenuHeader(
                              title: sections[index].title!,
                              count: sections[index].products.length,
                              style: _menuSectionStyle(
                                context,
                                sections[index],
                              ),
                            ),
                          )
                        else
                          const SliverToBoxAdapter(child: SizedBox(height: 4)),
                        SliverList.separated(
                          itemCount: sections[index].products.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, productIndex) {
                            final product =
                                sections[index].products[productIndex];
                            return ProductRow(
                              product: product,
                              onOpen: () => openProduct(store, product),
                              onAdd: product.available && store.open
                                  ? () => addProduct(store, product)
                                  : null,
                            );
                          },
                        ),
                        if (index != sections.length - 1)
                          const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ListenableBuilder(
        listenable: cart,
        builder: (context, _) => cart.itemCount == 0
            ? const SizedBox.shrink()
            : SizedBox(
                width: MediaQuery.sizeOf(context).width - 40,
                child: PrimaryAction(
                  label:
                      'View cart • ${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                  icon: Icons.shopping_cart_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, CustomerRoutes.cart),
                ),
              ),
      ),
    );
  }
}

class _StoreDetailHero extends StatelessWidget {
  const _StoreDetailHero({required this.store});

  final StoreData store;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.duskDeep, palette.duskMid, store.color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.circle,
            color: Colors.white.withValues(alpha: .08),
            size: 190,
          ),
          Icon(store.icon, color: Colors.white, size: 78),
          Positioned(
            right: 42,
            top: 62,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withValues(alpha: .58),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreMetricsCard extends StatelessWidget {
  const _StoreMetricsCard({required this.store});

  final StoreData store;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final hours = store.openingTime == null
        ? 'Not set'
        : '${_talaShortHour(store.openingTime!)}–${_talaShortHour(store.closingTime ?? '')}';
    final metrics = [
      _StoreMetricData(
        value: store.open ? 'Open' : 'Closed',
        label: 'Status',
        icon: store.open ? Icons.check_circle_rounded : Icons.schedule_rounded,
        color: store.open ? success : danger,
      ),
      _StoreMetricData(
        value: hours,
        label: 'Hours',
        icon: Icons.schedule_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      _StoreMetricData(
        value: '${store.products.length}',
        label: 'Items',
        icon: Icons.inventory_2_rounded,
        color: palette.ratingStar,
      ),
      _StoreMetricData(
        value: '${store.categories.length}',
        label: 'Categories',
        icon: Icons.grid_view_rounded,
        color: palette.positive,
      ),
    ];
    return Container(
      key: const Key('store-metrics-card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: palette.duskDeep.withValues(alpha: .1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(14) > 19;
          if (compact) {
            return Column(
              children: [
                _StoreMetricRow(metrics: metrics.take(2).toList()),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: palette.line),
                ),
                _StoreMetricRow(metrics: metrics.skip(2).toList()),
              ],
            );
          }
          return _StoreMetricRow(metrics: metrics);
        },
      ),
    );
  }
}

class _StoreMetricData {
  const _StoreMetricData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _StoreMetricRow extends StatelessWidget {
  const _StoreMetricRow({required this.metrics});

  final List<_StoreMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(child: _StoreMetricCell(metric: metrics[index])),
          if (index != metrics.length - 1)
            Container(width: 1, height: 50, color: palette.line),
        ],
      ],
    );
  }
}

class _StoreMetricCell extends StatelessWidget {
  const _StoreMetricCell({required this.metric});

  final _StoreMetricData metric;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(metric.icon, color: metric.color, size: 15),
                const SizedBox(width: 5),
                Text(
                  metric.value,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.quiet,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreMenuSection {
  const _StoreMenuSection({
    required this.categoryId,
    required this.title,
    required this.products,
  });

  final int? categoryId;
  final String? title;
  final List<ProductData> products;
}

_DashboardCategoryStyle _menuSectionStyle(
  BuildContext context,
  _StoreMenuSection section,
) => section.categoryId == null
    ? _DashboardCategoryStyle(
        Icons.local_dining_rounded,
        Theme.of(context).colorScheme.primary,
      )
    : _categoryStyle(context, section.title!.toLowerCase());

/// Category shortcuts above the store menu. Purely visual: the selected id is
/// still owned by the page state.
class _StoreCategoryFilters extends StatelessWidget {
  const _StoreCategoryFilters({
    required this.categories,
    required this.products,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CategoryData> categories;
  final List<ProductData> products;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: ListView.separated(
      key: const Key('store-category-filters'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      itemCount: categories.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final id = index == 0 ? null : categories[index - 1].id;
        final label = id == null ? 'All' : categories[index - 1].name;
        return _StoreCategoryPill(
          label: label,
          count: id == null
              ? products.length
              : products.where((product) => product.categoryId == id).length,
          selected: selectedId == id,
          onTap: () => onSelected(id),
        );
      },
    ),
  );
}

class _StoreCategoryPill extends StatelessWidget {
  const _StoreCategoryPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count ${count == 1 ? 'item' : 'items'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: selected ? primary : palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? primary : palette.line),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: .22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : palette.quiet,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreMenuHeader extends StatelessWidget {
  const _StoreMenuHeader({
    required this.title,
    required this.count,
    required this.style,
  });

  final String title;
  final int count;
  final _DashboardCategoryStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                style.color.withValues(alpha: .18),
                palette.surface,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(style.icon, size: 17, color: style.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.text,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count ${count == 1 ? 'item' : 'items'}',
            style: TextStyle(
              color: palette.quiet,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
