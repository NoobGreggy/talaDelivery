part of '../../app.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Future<List<CustomerAddress>>? addressesFuture;
  CustomerAddress? selectedAddress;
  CustomerDeliveryQuote? deliveryQuote;
  bool quoteLoading = true;
  bool proceeding = false;
  String? quoteError;
  int quoteGeneration = 0;
  int? requestedStoreId;
  int? requestedAddressId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    addressesFuture ??= CustomerDependencyScope.of(context).addressRepository
        .list();
  }

  @override
  void dispose() {
    quoteGeneration++;
    super.dispose();
  }

  Future<CustomerDeliveryQuote?> refreshQuote() async {
    if (!mounted) return null;
    final dependencies = CustomerDependencyScope.of(context);
    final store = dependencies.cartController.store;
    final address = selectedAddress;
    if (store == null || address == null) return null;
    final generation = ++quoteGeneration;
    requestedStoreId = store.id;
    requestedAddressId = address.id;
    setState(() {
      quoteLoading = true;
      deliveryQuote = null;
      quoteError = null;
    });
    try {
      final quote = await dependencies.orderRepository.quoteDelivery(
        store: store,
        address: address,
      );
      if (!mounted ||
          generation != quoteGeneration ||
          dependencies.cartController.store?.id != store.id) {
        return null;
      }
      setState(() => deliveryQuote = quote);
      return quote;
    } catch (error) {
      if (mounted && generation == quoteGeneration) {
        setState(() => quoteError = apiErrorMessage(error));
      }
      return null;
    } finally {
      if (mounted && generation == quoteGeneration) {
        setState(() => quoteLoading = false);
      }
    }
  }

  void reloadAddresses() {
    quoteGeneration++;
    setState(() {
      addressesFuture = CustomerDependencyScope.of(context).addressRepository
          .list();
      requestedAddressId = null;
      requestedStoreId = null;
      deliveryQuote = null;
      quoteError = null;
      quoteLoading = true;
    });
  }

  Future<void> continueToCheckout() async {
    if (proceeding || quoteLoading || deliveryQuote == null) return;
    setState(() => proceeding = true);
    try {
      final quote = await refreshQuote();
      if (!mounted ||
          quote == null ||
          CustomerDependencyScope.of(context).cartController.isEmpty) {
        return;
      }
      await Navigator.pushNamed(
        context,
        CustomerRoutes.checkout,
        arguments: CustomerCheckoutRouteArgs(addressId: selectedAddress!.id),
      );
      if (mounted) reloadAddresses();
    } finally {
      if (mounted) {
        setState(() => proceeding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CustomerDependencyScope.of(context).cartController;
    return Scaffold(
      appBar: simpleBar('Your cart'),
      body: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (cart.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              subtitle: 'Choose an available product from a store.',
            );
          }
          return FutureBuilder<List<CustomerAddress>>(
            future: addressesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ApiErrorState(
                  messageText: apiErrorMessage(snapshot.error),
                  onRetry: reloadAddresses,
                );
              }
              final addresses = snapshot.data ?? const <CustomerAddress>[];
              if (addresses.isEmpty) {
                return EmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Delivery address required',
                  subtitle: 'Add an address to calculate the delivery fee before checkout.',
                  actionLabel: 'Add address',
                  action: () async {
                    await Navigator.pushNamed(
                      context,
                      CustomerRoutes.addressSetup,
                      arguments: const CustomerAddressRouteArgs(),
                    );
                    if (mounted) reloadAddresses();
                  },
                );
              }
              selectedAddress = addresses.firstWhere(
                (address) => address.id == selectedAddress?.id,
                orElse: () => addresses.firstWhere(
                  (address) => address.isDefault,
                  orElse: () => addresses.first,
                ),
              );
              if (requestedStoreId != cart.store!.id ||
                  requestedAddressId != selectedAddress!.id) {
                requestedStoreId = cart.store!.id;
                requestedAddressId = selectedAddress!.id;
                quoteLoading = true;
                deliveryQuote = null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) unawaited(refreshQuote());
                });
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        InfoCard(
                          child: Row(
                            children: [
                              StoreArtwork(
                                icon: cart.store!.icon,
                                color: cart.store!.color,
                                height: 54,
                                width: 54,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cart.store!.name,
                                      style: TextStyle(
                                        color: appPaletteOf(context).text,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'One store per order',
                                      style: TextStyle(
                                        color: appPaletteOf(context).quiet,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Add items'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...cart.lines.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CartItem(
                              name: line.product.name,
                              price: line.product.price,
                              quantity: line.quantity,
                              icon: line.product.icon,
                              onMinus: () => cart.setQuantity(
                                line.product.id,
                                line.quantity - 1,
                              ),
                              onPlus: line.quantity < line.product.stock
                                  ? () => cart.setQuantity(
                                      line.product.id,
                                      line.quantity + 1,
                                    )
                                  : () {},
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const CheckoutTitle(
                          icon: Icons.location_on_outlined,
                          title: 'Delivery address',
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          key: const Key('cart-delivery-address'),
                          isExpanded: true,
                          initialValue: selectedAddress!.id,
                          items: addresses
                              .map(
                                (address) => DropdownMenuItem(
                                  value: address.id,
                                  child: Text(
                                    '${address.label ?? 'Address'} • ${address.city}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: proceeding
                              ? null
                              : (id) {
                                  setState(
                                    () =>
                                        selectedAddress = addresses.firstWhere(
                                          (address) => address.id == id,
                                        ),
                                  );
                                  unawaited(refreshQuote());
                                },
                        ),
                        const SizedBox(height: 12),
                        if (quoteLoading)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text('Calculating delivery fee…'),
                                ),
                              ],
                            ),
                          ),
                        if (quoteError != null) ...[
                          AuthErrorBanner(errorMessage: quoteError),
                          TextButton(
                            onPressed: quoteLoading || proceeding
                                ? null
                                : refreshQuote,
                            child: const Text('Retry delivery fee'),
                          ),
                        ],
                        if (deliveryQuote != null) ...[
                          Text(
                            'Delivery zone: ${deliveryQuote!.zoneName} • ${deliveryQuote!.distanceKm.toStringAsFixed(2)} km',
                            key: const Key('cart-delivery-zone'),
                          ),
                          const SizedBox(height: 10),
                          PriceSummary(
                            subtotal: cart.subtotal,
                            delivery: deliveryQuote!.deliveryFee,
                            total: cart.subtotal + deliveryQuote!.deliveryFee,
                          ),
                        ],
                        const SizedBox(height: 15),
                        const InfoBanner(
                          icon: Icons.info_outline_rounded,
                          text: 'The delivery fee comes from the active admin zone covering your address. Prices and the fee are checked again when you place the order.',
                        ),
                      ],
                    ),
                  ),
                  BottomAction(
                    label: proceeding || quoteLoading
                        ? 'Calculating delivery fee…'
                        : deliveryQuote == null
                        ? 'Delivery unavailable'
                        : 'Continue to checkout • ${peso(cart.subtotal + deliveryQuote!.deliveryFee)}',
                    enabled:
                        !proceeding && !quoteLoading && deliveryQuote != null,
                    onTap: continueToCheckout,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
