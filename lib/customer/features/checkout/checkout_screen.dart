part of '../../app.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.initialAddressId});
  final int? initialAddressId;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final notesController = TextEditingController();
  Future<List<CustomerAddress>>? addressesFuture;
  CustomerAddress? selectedAddress;
  bool submitting = false;
  String? errorMessage;
  CustomerDeliveryQuote? deliveryQuote;
  bool quoteLoading = true;
  String? quoteError;
  int quoteGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    addressesFuture ??= CustomerDependencyScope.of(context).addressRepository
        .list();
  }

  @override
  void dispose() {
    quoteGeneration++;
    notesController.dispose();
    super.dispose();
  }

  Future<CustomerDeliveryQuote?> refreshQuote() async {
    if (!mounted) return null;
    final dependencies = CustomerDependencyScope.of(context);
    final store = dependencies.cartController.store;
    final address = selectedAddress;
    if (store == null || address == null) return null;
    final generation = ++quoteGeneration;
    setState(() {
      quoteLoading = true;
      quoteError = null;
      deliveryQuote = null;
    });
    try {
      final result = await dependencies.orderRepository.quoteDelivery(
        store: store,
        address: address,
      );
      if (!mounted || generation != quoteGeneration) return null;
      setState(() => deliveryQuote = result);
      return result;
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

  Future<void> placeOrder() async {
    if (submitting || quoteLoading || deliveryQuote == null) return;
    final dependencies = CustomerDependencyScope.of(context);
    final cart = dependencies.cartController;
    final address = selectedAddress;
    if (cart.isEmpty || cart.store == null) {
      message(context, 'Your cart is empty.', kind: ToastKind.error);
      return;
    }
    if (address == null) {
      message(context, 'Choose a delivery address.', kind: ToastKind.error);
      return;
    }
    setState(() {
      submitting = true;
      errorMessage = null;
    });
    try {
      // Refresh admin zone settings before confirming; order creation recalculates on the server.
      final quote = await refreshQuote();
      if (quote == null || !mounted) return;
      final confirmed = await confirmAction(
        context,
        title: 'Place this order?',
        body:
            '${cart.store!.name} • ${peso(cart.subtotal + quote.deliveryFee)} including ${peso(quote.deliveryFee)} delivery fee',
        confirmLabel: 'Place order',
      );
      if (!confirmed || !mounted) return;
      final order = await dependencies.orderRepository.create(
        store: cart.store!,
        lines: cart.lines,
        address: address,
        notes: notesController.text,
      );
      cart.clear();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        CustomerRoutes.orderSuccess,
        (route) => route.settings.name == CustomerRoutes.home,
        arguments: order,
      );
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } catch (error) {
      if (mounted) setState(() => errorMessage = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CustomerDependencyScope.of(context).cartController;
    if (cart.isEmpty) {
      return Scaffold(
        appBar: simpleBar('Checkout'),
        body: const EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          subtitle: 'Add products before checking out.',
        ),
      );
    }
    return Scaffold(
      appBar: simpleBar('Checkout'),
      body: FutureBuilder<List<CustomerAddress>>(
        future: addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(
              messageText: apiErrorMessage(snapshot.error),
              onRetry: () => setState(() {
                addressesFuture = CustomerDependencyScope.of(context)
                    .addressRepository
                    .list();
              }),
            );
          }
          final addresses = snapshot.data ?? const [];
          if (selectedAddress == null && addresses.isNotEmpty) {
            selectedAddress = addresses.firstWhere(
              (item) => item.id == widget.initialAddressId,
              orElse: () => addresses.firstWhere(
                (item) => item.isDefault,
                orElse: () => addresses.first,
              ),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(refreshQuote());
            });
          }
          if (addresses.isEmpty) {
            return EmptyState(
              icon: Icons.location_off_outlined,
              title: 'Delivery address required',
              subtitle: 'Add an address before placing your order.',
              action: () async {
                await Navigator.pushNamed(
                  context,
                  CustomerRoutes.addressSetup,
                  arguments: const CustomerAddressRouteArgs(),
                );
                if (mounted) {
                  setState(() {
                    addressesFuture = CustomerDependencyScope.of(context)
                        .addressRepository
                        .list();
                  });
                }
              },
              actionLabel: 'Add address',
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const CheckoutTitle(
                      icon: Icons.location_on_outlined,
                      title: 'Delivery address',
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: selectedAddress?.id,
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
                          .toList(growable: false),
                      onChanged: submitting
                          ? null
                          : (id) {
                              setState(
                                () => selectedAddress = addresses.firstWhere(
                                  (address) => address.id == id,
                                ),
                              );
                              unawaited(refreshQuote());
                            },
                    ),
                    const SizedBox(height: 10),
                    InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedAddress!.recipientName,
                            style: TextStyle(
                              color: appPaletteOf(context).text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAddress!.formatted,
                            style: TextStyle(
                              color: appPaletteOf(context).quiet,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAddress!.phone,
                            style: TextStyle(
                              color: appPaletteOf(context).quiet,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CheckoutTitle(
                      icon: Icons.sticky_note_2_outlined,
                      title: 'Delivery notes',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Optional instructions for the rider',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CheckoutTitle(
                      icon: Icons.payments_outlined,
                      title: 'Payment',
                    ),
                    const SizedBox(height: 10),
                    InfoCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radio_button_checked_rounded,
                            color: sky,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cash on Delivery',
                              style: TextStyle(
                                color: appPaletteOf(context).text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (quoteLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Expanded(child: Text('Calculating delivery fee…')),
                          ],
                        ),
                      ),
                    if (quoteError != null) ...[
                      AuthErrorBanner(errorMessage: quoteError),
                      TextButton(
                        onPressed: quoteLoading || submitting
                            ? null
                            : refreshQuote,
                        child: const Text('Retry delivery fee'),
                      ),
                    ],
                    if (deliveryQuote != null) ...[
                      Text(
                        'Delivery zone: ${deliveryQuote!.zoneName} • ${deliveryQuote!.distanceKm.toStringAsFixed(2)} km',
                        key: const Key('checkout-delivery-zone'),
                      ),
                      const SizedBox(height: 10),
                      PriceSummary(
                        subtotal: cart.subtotal,
                        delivery: deliveryQuote!.deliveryFee,
                        total: cart.subtotal + deliveryQuote!.deliveryFee,
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      AuthErrorBanner(errorMessage: errorMessage),
                    ],
                  ],
                ),
              ),
              BottomAction(
                label: submitting
                    ? 'Placing order…'
                    : quoteLoading
                    ? 'Calculating delivery fee…'
                    : deliveryQuote == null
                    ? 'Delivery unavailable'
                    : 'Place order • ${peso(cart.subtotal + deliveryQuote!.deliveryFee)}',
                enabled: !submitting && !quoteLoading && deliveryQuote != null,
                onTap: placeOrder,
              ),
            ],
          );
        },
      ),
    );
  }
}
