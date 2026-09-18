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
  CustomerRealtimeController? realtime;
  int seenNotificationVersion = 0;
  String? selectedCategory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRealtime = CustomerDependencyScope.of(context).realtime;
    if (realtime != nextRealtime) {
      realtime?.removeListener(onNotificationEvent);
      realtime = nextRealtime;
      seenNotificationVersion = nextRealtime.notificationVersion;
      nextRealtime.addListener(onNotificationEvent);
    }
    future ??= load();
  }

  void onNotificationEvent() {
    if (realtime!.notificationVersion == seenNotificationVersion) return;
    seenNotificationVersion = realtime!.notificationVersion;
    unawaited(_reloadAfterEvent());
  }

  Future<void> _reloadAfterEvent() async {
    try {
      final current = await future;
      if (!mounted || current == null) return;
      final notifications = await CustomerDependencyScope.of(context)
          .notificationRepository
          .list();
      if (!mounted) return;
      setState(() {
        future = Future.value(
          _CustomerHomeData(
            stores: current.stores,
            addresses: current.addresses,
            notifications: notifications,
          ),
        );
      });
    } catch (_) {
      // Manual refresh remains available if the event-time fetch fails.
    }
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
    setState(() {
      future = next;
    });
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

  List<StoreData> filteredStores(List<StoreData> stores) {
    final selection = selectedCategory;
    if (selection == null) return stores;
    return stores
        .where(
          (store) => store.categories.any(
            (category) => category.name.toLowerCase() == selection,
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    realtime?.removeListener(onNotificationEvent);
    storeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return FutureBuilder<_CustomerHomeData>(
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
        final unread = data.notifications.where((item) => !item.isRead).length;
        final categories = _DashboardCategories.fromStores(data.stores);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            children: [
              _DashboardHeader(
                address: address,
                unread: unread,
                onAddressTap: () async {
                  await Navigator.pushNamed(context, CustomerRoutes.addresses);
                  if (mounted) reload();
                },
                onNotificationsTap: () async {
                  await Navigator.pushNamed(
                    context,
                    CustomerRoutes.notifications,
                  );
                  if (mounted) reload();
                },
              ),
              const SizedBox(height: 22),
              Text(
                _timeGreeting(),
                style: TextStyle(
                  color: tint(shade(sky, .3), .12),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'What you need,',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 29,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -1.2,
                ),
              ),
              Text(
                'nearby.',
                style: TextStyle(
                  color: palette.quiet,
                  fontSize: 29,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 18),
              TalaSearchField(
                key: const Key('home-store-search'),
                controller: storeSearchController,
                onSubmitted: (_) => openStoreSearch(),
              ),
              const SizedBox(height: 30),
              _DashboardCategories(
                categories: categories,
                selected: selectedCategory,
                onSelected: (name) => setState(() => selectedCategory = name),
              ),
              const SizedBox(height: 6),
              _DashboardMarkets(
                stores: filteredStores(data.stores),
                selected: selectedCategory,
                onSeeAll: data.stores.isEmpty
                    ? null
                    : () => Navigator.pushNamed(context, CustomerRoutes.stores),
                onTap: (store) => Navigator.pushNamed(
                  context,
                  CustomerRoutes.storeDetails,
                  arguments: store,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _DashboardCategoryStyle {
  const _DashboardCategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;
}

_DashboardCategoryStyle _categoryStyle(String name) {
  final key = name.toLowerCase();
  if (key.contains('grocery') ||
      key.contains('produce') ||
      key.contains('fresh') ||
      key.contains('market')) {
    return _DashboardCategoryStyle(Icons.local_grocery_store_rounded, success);
  }
  if (key.contains('pharm') ||
      key.contains('medic') ||
      key.contains('drug') ||
      key.contains('health') ||
      key.contains('wellness')) {
    return _DashboardCategoryStyle(Icons.medication_rounded, Color(0xFF7C5CE8));
  }
  if (key.contains('home') ||
      key.contains('household') ||
      key.contains('hardware')) {
    return _DashboardCategoryStyle(Icons.home_rounded, Color(0xFFF59E0B));
  }
  if (key.contains('personal') ||
      key.contains('care') ||
      key.contains('beauty') ||
      key.contains('body')) {
    return _DashboardCategoryStyle(Icons.brush_rounded, Color(0xFFEC4899));
  }
  if (key.contains('drink') ||
      key.contains('beverage') ||
      key.contains('ready')) {
    return _DashboardCategoryStyle(Icons.local_cafe_rounded, Color(0xFF14B8A6));
  }
  return _DashboardCategoryStyle(Icons.category_rounded, sky);
}

class _DashboardCategories extends StatelessWidget {
  const _DashboardCategories({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, _DashboardCategoryStyle> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  static Map<String, _DashboardCategoryStyle> fromStores(
    List<StoreData> stores,
  ) {
    final result = <String, _DashboardCategoryStyle>{};
    for (final store in stores) {
      for (final category in store.categories) {
        result.putIfAbsent(
          category.name.toLowerCase().trim(),
          () => _categoryStyle(category.name),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BROWSE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.quiet,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Categories',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => onSelected(null),
              child: const Text('Show all'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height:
              116 +
              (MediaQuery.textScalerOf(context).scale(11) - 11).clamp(0, 100) +
              (MediaQuery.textScalerOf(context).scale(9) - 9).clamp(0, 100),
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              TalaCategoryChip(
                label: 'All',
                icon: Icons.grid_view_rounded,
                color: sky,
                subtitle: 'Nearby',
                selected: selected == null,
                onTap: () => onSelected(null),
              ),
              ...categories.entries.map((entry) {
                final name = entry.key;
                final style = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: TalaCategoryChip(
                    label: _titleCase(name),
                    icon: style.icon,
                    color: style.color,
                    selected: selected == name,
                    onTap: () => onSelected(name),
                  ),
                );
              }),
            ],
          ),
        ),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Store categories will appear here when available.',
              style: TextStyle(color: palette.quiet, fontSize: 12),
            ),
          ),
      ],
    );
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value.substring(0, 1).toUpperCase() + value.substring(1);
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.address,
    required this.unread,
    required this.onAddressTap,
    required this.onNotificationsTap,
  });

  final CustomerAddress? address;
  final int unread;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final cart = CustomerDependencyScope.of(context).cartController;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onAddressTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: .05),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/tala_rider.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELIVER TO',
                          style: TextStyle(
                            color: palette.quiet,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                address == null
                                    ? 'Add a delivery address'
                                    : '${address!.label ?? 'Address'} • ${address!.city}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: palette.quiet,
                              size: 17,
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
        ),
        const SizedBox(width: 8),
        _HeaderAction(
          tooltip: 'Notifications',
          onTap: onNotificationsTap,
          child: Badge.count(
            key: const Key('home-unread-badge'),
            count: unread,
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_none_rounded, size: 21),
          ),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: cart,
          builder: (context, _) => _HeaderAction(
            tooltip: 'Cart',
            onTap: () => Navigator.pushNamed(context, CustomerRoutes.cart),
            child: Badge.count(
              count: cart.itemCount,
              isLabelVisible: cart.itemCount > 0,
              child: const Icon(Icons.shopping_cart_outlined, size: 21),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: .05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _DashboardMarkets extends StatelessWidget {
  const _DashboardMarkets({
    required this.stores,
    required this.selected,
    required this.onTap,
    this.onSeeAll,
  });

  final List<StoreData> stores;
  final String? selected;
  final ValueChanged<StoreData> onTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEAR YOU',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.quiet,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Available stores',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onSeeAll != null)
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 14),
        if (stores.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: palette.emptyIcon,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  selected == null
                      ? 'No markets available'
                      : 'No nearby matches',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected == null
                      ? 'Active markets added in Laravel will appear here.'
                      : 'Try another category.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.quiet, fontSize: 11),
                ),
              ],
            ),
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Column(
              key: ValueKey('markets-$selected'),
              children: [
                for (final store in stores)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: TalaMarketCard(
                      store: store,
                      onTap: () => onTap(store),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
