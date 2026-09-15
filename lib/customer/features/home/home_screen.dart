part of '../../app.dart';

class _CustomerHomeData {
  const _CustomerHomeData({
    required this.stores,
    required this.addresses,
    required this.notifications,
  });

  final List<StoreData> stores;
  final List<CustomerAddress> addresses;
  final List<CustomerNotification> notifications;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final storeSearchController = TextEditingController();
  Future<_CustomerHomeData>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<_CustomerHomeData> load() async {
    final dependencies = CustomerDependencyScope.of(context);
    final results = await Future.wait<dynamic>([
      dependencies.catalogRepository.listStores(),
      dependencies.addressRepository.list(),
      dependencies.notificationRepository.list(),
    ]);
    return _CustomerHomeData(
      stores: results[0] as List<StoreData>,
      addresses: results[1] as List<CustomerAddress>,
      notifications: results[2] as List<CustomerNotification>,
    );
  }

  Future<void> reload() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  void openStoreSearch() {
    final query = storeSearchController.text.trim();
    Navigator.pushNamed(
      context,
      CustomerRoutes.stores,
      arguments: CustomerStoreListingRouteArgs(initialSearch: query),
    );
  }

  @override
  void dispose() {
    storeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = CustomerRouteScope.of(context).session.user;
    final cart = CustomerDependencyScope.of(context).cartController;
    final firstName =
        user?.name.trim().split(RegExp(r'\s+')).first ?? 'Customer';
    final initials =
        user?.name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join() ??
        'CU';
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_CustomerHomeData>(
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
          final data = snapshot.data!;
          final address = data.addresses.cast<CustomerAddress?>().firstWhere(
            (item) => item?.isDefault == true,
            orElse: () => data.addresses.isEmpty ? null : data.addresses.first,
          );
          final unread = data.notifications
              .where((item) => !item.isRead)
              .length;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 28),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: appPaletteOf(context).avatarFill,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: sky,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: appPaletteOf(context).quiet,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            firstName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await Navigator.pushNamed(
                          context,
                          CustomerRoutes.notifications,
                        );
                        if (mounted) reload();
                      },
                      icon: Badge.count(
                        count: unread,
                        isLabelVisible: unread > 0,
                        child: const Icon(Icons.notifications_none_rounded),
                      ),
                    ),
                    const SizedBox(width: 3),
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
                ),
                const SizedBox(height: 20),
                Material(
                  color: appPaletteOf(context).softBlue,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(17),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        CustomerRoutes.addresses,
                      );
                      if (mounted) reload();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: sky),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DELIVER TO',
                                  style: TextStyle(
                                    color: sky,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  address == null
                                      ? 'Add a delivery address'
                                      : '${address.label ?? 'Address'} • ${address.city}',
                                  style: TextStyle(
                                    color: appPaletteOf(context).text,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: sky,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('home-store-search'),
                  controller: storeSearchController,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  onSubmitted: (_) => openStoreSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search stores',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      onPressed: openStoreSearch,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SectionHeading(
                  title: 'Available stores',
                  action: data.stores.isEmpty ? null : 'See all',
                  onTap: data.stores.isEmpty
                      ? null
                      : () =>
                            Navigator.pushNamed(context, CustomerRoutes.stores),
                ),
                const SizedBox(height: 13),
                if (data.stores.isEmpty)
                  const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No stores available',
                    subtitle: 'Active stores added in Laravel will appear here automatically.',
                  )
                else
                  ...data.stores
                      .take(3)
                      .map(
                        (store) => Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: StoreCard(
                            store: store,
                            onTap: () => Navigator.pushNamed(
                              context,
                              CustomerRoutes.storeDetails,
                              arguments: store,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
