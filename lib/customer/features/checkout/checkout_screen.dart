part of '../../app.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final notesController = TextEditingController();
  Future<List<CustomerAddress>>? addressesFuture;
  CustomerAddress? selectedAddress;
  bool submitting = false;
  String? errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    addressesFuture ??= CustomerDependencyScope.of(context).addressRepository
        .list();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> placeOrder() async {
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
    final confirmed = await confirmAction(
      context,
      title: 'Place this order?',
      body: '${cart.store!.name} • ${peso(cart.subtotal)} before delivery fee',
      confirmLabel: 'Place order',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      submitting = true;
      errorMessage = null;
    });
    try {
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
              onRetry: () => setState(
                () =>
                    addressesFuture = CustomerDependencyScope.of(context)
                        .addressRepository
                        .list(),
              ),
            );
          }
          final addresses = snapshot.data ?? const [];
          selectedAddress ??= addresses.cast<CustomerAddress?>().firstWhere(
            (item) => item?.isDefault == true,
            orElse: () => addresses.isEmpty ? null : addresses.first,
          );
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
                  setState(
                    () =>
                        addressesFuture = CustomerDependencyScope.of(context)
                            .addressRepository
                            .list(),
                  );
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
                      onChanged: (id) => setState(
                        () => selectedAddress = addresses.firstWhere(
                          (address) => address.id == id,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedAddress!.recipientName,
                            style: const TextStyle(
                              color: text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAddress!.formatted,
                            style: const TextStyle(color: quiet),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAddress!.phone,
                            style: const TextStyle(color: quiet),
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
                    const InfoCard(
                      child: Row(
                        children: [
                          Icon(Icons.radio_button_checked_rounded, color: sky),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cash on Delivery',
                              style: TextStyle(
                                color: text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    PriceSummary(subtotal: cart.subtotal),
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
                    : 'Place order • ${peso(cart.subtotal)} + delivery',
                enabled: !submitting,
                onTap: placeOrder,
              ),
            ],
          );
        },
      ),
    );
  }
}
