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
  int? latestUnread;
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
        latestUnread = notifications.where((item) => !item.isRead).length;
        future = Future.value(
          _CustomerHomeData(
            stores: current.stores,
            addresses: current.addresses,
            notifications: notifications,
          ),
        );
      });
    } catch (_) {
      // Pull-to-refresh remains available if the event-time fetch fails.
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
      latestUnread = null;
      future = next;
    });
    await next;
  }

  void openStoreSearch() {
    Navigator.pushNamed(
      context,
      CustomerRoutes.stores,
      arguments: CustomerStoreListingRouteArgs(
        initialSearch: storeSearchController.text.trim(),
      ),
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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: FutureBuilder<_CustomerHomeData>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final address = data?.addresses.cast<CustomerAddress?>().firstWhere(
          (item) => item?.isDefault == true,
          orElse: () => data.addresses.isEmpty ? null : data.addresses.first,
        );
        final unread =
            latestUnread ??
            data?.notifications.where((item) => !item.isRead).length ??
            0;
        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _DashboardHero(
                  customerName:
                      CustomerRouteScope.of(context).session.user?.name ??
                      'Customer',
                  address: address,
                  unread: unread,
                  searchController: storeSearchController,
                  onSearch: openStoreSearch,
                  onAddressTap: () async {
                    await Navigator.pushNamed(
                      context,
                      CustomerRoutes.addresses,
                    );
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
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverToBoxAdapter(child: _DashboardSkeleton())
              else if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: _DashboardInlineError(
                    messageText: apiErrorMessage(snapshot.error),
                    onRetry: reload,
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _DashboardCategories(
                    categories: _categoryNames(data!.stores),
                    selected: selectedCategory,
                    onSelected: (name) =>
                        setState(() => selectedCategory = name),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TalaPromoStrip(
                    onTap: () => message(
                      context,
                      'Tala Plus membership is coming soon.',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DashboardMarkets(
                    stores: filteredStores(data.stores),
                    selected: selectedCategory,
                    onChangeAddress: () async {
                      await Navigator.pushNamed(
                        context,
                        CustomerRoutes.addresses,
                      );
                      if (mounted) reload();
                    },
                    onSeeAll: data.stores.isEmpty
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            CustomerRoutes.stores,
                          ),
                    onTap: (store) => Navigator.pushNamed(
                      context,
                      CustomerRoutes.storeDetails,
                      arguments: store,
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: _customerScrollClearance(context)),
              ),
            ],
          ),
        );
      },
    ),
  );

  static List<String> _categoryNames(List<StoreData> stores) {
    final names = <String>{};
    for (final store in stores) {
      for (final category in store.categories) {
        names.add(category.name.toLowerCase().trim());
      }
    }
    final sorted = names.toList(growable: false);
    sorted.sort();
    return sorted;
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.customerName,
    required this.address,
    required this.unread,
    required this.searchController,
    required this.onSearch,
    required this.onAddressTap,
    required this.onNotificationsTap,
  });
  final String customerName;
  final CustomerAddress? address;
  final int unread;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) => TalaDuskSky(
    animate: !MediaQuery.disableAnimationsOf(context),
    shootingStar: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 22,
        20,
        50,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Change delivery address',
                  child: InkWell(
                    onTap: onAddressTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_timeGreeting()}, ${_firstName(customerName)} · delivering to',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  address == null
                                      ? 'Add a delivery address'
                                      : '${address!.label ?? 'Address'} · ${address!.city}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Notifications, $unread unread',
                child: InkWell(
                  onTap: onNotificationsTap,
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .25),
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          if (unread > 0)
                            Positioned(
                              key: const Key('home-unread-badge'),
                              right: -3,
                              top: -3,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: appPaletteOf(context).urgent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: appPaletteOf(context).duskDeep,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .22)),
            ),
            child: TextField(
              key: const Key('home-store-search'),
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search stores, dishes, groceries',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 14,
                ),
                prefixIcon: IconButton(
                  tooltip: 'Search stores',
                  onPressed: onSearch,
                  icon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: .75),
                    size: 18,
                  ),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  static String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static String _firstName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return 'Customer';
    return normalized.split(RegExp(r'\s+')).first;
  }
}

class _DashboardCategories extends StatelessWidget {
  const _DashboardCategories({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    final entries = <String?>[null, ...categories];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      child: Container(
        key: const Key('dashboard-categories-card'),
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Categories',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onSelected(null),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height:
                  112 +
                  (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
                    0,
                    28,
                  ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final name = entries[index];
                  final style = _categoryStyle(context, name);
                  return TalaCategoryChip(
                    label: name == null ? 'All' : _titleCase(name),
                    icon: style.icon,
                    color: style.color,
                    selected: selected == name,
                    onTap: () => onSelected(name),
                  );
                },
              ),
            ),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Store categories will appear here when available.',
                    style: TextStyle(color: palette.quiet, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _titleCase(String value) => value.isEmpty
      ? value
      : value.substring(0, 1).toUpperCase() + value.substring(1);
}

class _DashboardCategoryStyle {
  const _DashboardCategoryStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_DashboardCategoryStyle _categoryStyle(BuildContext context, String? name) {
  final palette = appPaletteOf(context);
  final scheme = Theme.of(context).colorScheme;
  final key = name ?? '';
  if (key.contains('grocery') || key.contains('market')) {
    return _DashboardCategoryStyle(
      Icons.local_grocery_store_rounded,
      palette.positive,
    );
  }
  if (key.contains('pharm') || key.contains('health')) {
    return _DashboardCategoryStyle(Icons.medication_rounded, palette.urgent);
  }
  if (key.contains('parcel') || key.contains('delivery')) {
    return _DashboardCategoryStyle(
      Icons.inventory_2_rounded,
      palette.ratingStar,
    );
  }
  if (key.contains('deal') || key.contains('promo')) {
    return _DashboardCategoryStyle(Icons.local_offer_rounded, scheme.secondary);
  }
  return _DashboardCategoryStyle(
    name == null ? Icons.grid_view_rounded : Icons.restaurant_rounded,
    scheme.primary,
  );
}

class _TalaPromoStrip extends StatelessWidget {
  const _TalaPromoStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Semantics(
        button: true,
        label: 'Learn about Tala Plus membership',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                palette.ratingStar.withValues(alpha: .14),
                palette.surface,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.ratingStar.withValues(alpha: .3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.ratingStar,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tala Plus makes every delivery brighter',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Membership benefits are coming soon',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    required this.onChangeAddress,
    this.onSeeAll,
  });
  final List<StoreData> stores;
  final String? selected;
  final ValueChanged<StoreData> onTap;
  final VoidCallback onChangeAddress;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stores near you',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (onSeeAll != null)
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
          const SizedBox(height: 10),
          if (stores.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.line),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    color: palette.ratingStar,
                    size: 46,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selected == null
                        ? 'No stores near you yet'
                        : 'No stores in this category',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selected == null
                        ? 'Try another delivery location.'
                        : 'Choose another category to keep browsing.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onChangeAddress,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Change address'),
                  ),
                ],
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey('stores-$selected'),
                children: [
                  for (var index = 0; index < stores.length; index++) ...[
                    TalaMarketCard(
                      store: stores[index],
                      onTap: () => onTap(stores[index]),
                    ),
                    if (index != stores.length - 1) const SizedBox(height: 26),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    Widget block(double height, {double? width, double radius = 16}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: palette.line.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(20, width: 110),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var index = 0; index < 4; index++) ...[
                block(58, width: 58, radius: 18),
                if (index < 3) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 34),
          block(20, width: 150),
          const SizedBox(height: 18),
          block(280, width: double.infinity, radius: 24),
        ],
      ),
    );
  }
}

class _DashboardInlineError extends StatelessWidget {
  const _DashboardInlineError({
    required this.messageText,
    required this.onRetry,
  });
  final String messageText;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final palette = appPaletteOf(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(messageText, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
