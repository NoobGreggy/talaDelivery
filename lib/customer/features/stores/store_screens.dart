part of '../../app.dart';

class StoreListingPage extends StatefulWidget {
  const StoreListingPage({super.key, this.initialFilter = 0});

  final int initialFilter;

  @override
  State<StoreListingPage> createState() => _StoreListingPageState();
}

class _StoreListingPageState extends State<StoreListingPage> {
  final searchController = TextEditingController();
  CustomerCatalogRepository? repository;
  Future<List<StoreData>>? future;
  Timer? debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository ??= CustomerDependencyScope.of(context).catalogRepository;
    future ??= repository!.listStores();
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
      setState(() => future = repository!.listStores(search: value));
    });
  }

  void reload() => setState(
    () => future = repository!.listStores(search: searchController.text),
  );

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

  void reload() => setState(
    () =>
        future = CustomerDependencyScope.of(context).catalogRepository
            .getStore(widget.store.id),
  );

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
          final products = store.products
              .where(
                (product) =>
                    categoryId == null || product.categoryId == categoryId,
              )
              .toList(growable: false);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: dark,
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
                  background: StoreArtwork(
                    icon: store.icon,
                    color: store.color,
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
                      if (store.categories.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 41,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: categoryId == null,
                                onSelected: (_) =>
                                    setState(() => categoryId = null),
                              ),
                              ...store.categories.map(
                                (category) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    label: Text(category.name),
                                    selected: categoryId == category.id,
                                    onSelected: (_) => setState(
                                      () => categoryId = category.id,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 23),
                      const SectionHeading(title: 'Products'),
                    ],
                  ),
                ),
              ),
              if (products.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products available',
                    subtitle: 'Available products from Laravel appear here.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  sliver: SliverList.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductRow(
                        product: product,
                        onOpen: () => openProduct(store, product),
                        onAdd: product.available && store.open
                            ? () => addProduct(store, product)
                            : null,
                      );
                    },
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
