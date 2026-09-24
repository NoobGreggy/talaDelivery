part of '../../app.dart';

class AddressSetupPage extends StatefulWidget {
  const AddressSetupPage({super.key, this.firstRun = false, this.address});

  final bool firstRun;
  final CustomerAddress? address;

  bool get editing => address != null;

  @override
  State<AddressSetupPage> createState() => _AddressSetupPageState();
}

class _AddressSetupPageState extends State<AddressSetupPage> {
  final formKey = GlobalKey<FormState>();
  final labelController = TextEditingController(text: 'Home');
  final recipientController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final barangayController = TextEditingController();
  final cityController = TextEditingController();
  final provinceController = TextEditingController();
  final postalController = TextEditingController();
  final notesController = TextEditingController();
  CustomerAddressViewModel? viewModel;
  bool initialized = false;
  CustomerMapPoint? selectedPoint;
  String? mapError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    viewModel ??= CustomerAddressViewModel(
      CustomerDependencyScope.of(context).addressRepository,
    );
    if (initialized) return;
    initialized = true;
    final existing = widget.address;
    final user = CustomerRouteScope.of(context).session.user;
    labelController.text = existing?.label ?? 'Home';
    recipientController.text = existing?.recipientName ?? user?.name ?? '';
    phoneController.text = existing?.phone ?? user?.phone ?? '';
    addressController.text = existing?.addressLine ?? '';
    barangayController.text = existing?.barangay ?? '';
    cityController.text = existing?.city ?? '';
    provinceController.text = existing?.province ?? '';
    postalController.text = existing?.postalCode ?? '';
    notesController.text = existing?.notes ?? '';
    if (existing?.latitude != null && existing?.longitude != null) {
      selectedPoint = CustomerMapPoint(
        existing!.latitude!,
        existing.longitude!,
      );
    }
  }

  @override
  void dispose() {
    labelController.dispose();
    recipientController.dispose();
    phoneController.dispose();
    addressController.dispose();
    barangayController.dispose();
    cityController.dispose();
    provinceController.dispose();
    postalController.dispose();
    notesController.dispose();
    viewModel?.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (selectedPoint == null) {
      setState(() {
        mapError = 'Tap the map to select the exact delivery location.';
      });
      return;
    }
    final request = CustomerAddressRequest(
      label: labelController.text,
      recipientName: recipientController.text,
      phone: phoneController.text,
      addressLine: addressController.text,
      barangay: barangayController.text,
      city: cityController.text,
      province: provinceController.text,
      postalCode: postalController.text,
      latitude: selectedPoint!.latitude,
      longitude: selectedPoint!.longitude,
      notes: notesController.text,
      isDefault: widget.firstRun || widget.address?.isDefault == true,
    );
    final saved = widget.address == null
        ? await viewModel!.create(request)
        : await viewModel!.update(widget.address!.id, request);
    if (!mounted || saved == null) return;

    message(
      context,
      widget.editing ? 'Address updated.' : 'Address saved.',
      kind: ToastKind.success,
    );
    if (widget.firstRun) {
      final routes = CustomerRouteScope.of(context)..completeAddressSetup();
      final destination = routes.destinationAfterAddressSetup();
      Navigator.of(context).pushNamedAndRemoveUntil(
        destination.name!,
        (_) => false,
        arguments: destination.arguments,
      );
    } else {
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel!,
    builder: (context, _) => Scaffold(
      appBar: widget.firstRun
          ? null
          : simpleBar(widget.editing ? 'Edit address' : 'Add address'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.firstRun) ...[
                        const Brand(size: 24),
                        const SizedBox(height: 28),
                      ],
                      Text(
                        widget.editing
                            ? 'Update delivery address'
                            : 'Where should we deliver?',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your account details are prefilled. Add only the delivery location.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('address-recipient'),
                        controller: recipientController,
                        readOnly: recipientController.text.isNotEmpty,
                        validator: (value) => CustomerValidators.requiredText(
                          value,
                          'Recipient name',
                        ),
                        decoration: InputDecoration(
                          labelText: 'Recipient name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          errorText: viewModel!.fieldError('recipient_name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('address-phone'),
                        controller: phoneController,
                        readOnly: phoneController.text.isNotEmpty,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            CustomerValidators.phone(value, required: true),
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          errorText: viewModel!.fieldError('phone'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Delivery location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      CustomerAddressMapPicker(
                        selectedPoint: selectedPoint,
                        surfaceBuilder: CustomerDependencyScope.of(context)
                            .addressMapSurfaceBuilder,
                        onChanged: (point) => setState(() {
                          selectedPoint = point;
                          mapError = null;
                        }),
                      ),
                      if (mapError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          mapError!,
                          key: const Key('address-map-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('address-label'),
                        controller: labelController,
                        decoration: InputDecoration(
                          labelText: 'Label',
                          hintText: 'Home, Work, or School',
                          prefixIcon: const Icon(
                            Icons.bookmark_outline_rounded,
                          ),
                          errorText: viewModel!.fieldError('label'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('address-line'),
                        controller: addressController,
                        validator: (value) => CustomerValidators.requiredText(
                          value,
                          'Street address',
                        ),
                        decoration: InputDecoration(
                          labelText: 'House number and street',
                          prefixIcon: const Icon(Icons.home_outlined),
                          errorText: viewModel!.fieldError('address_line'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('address-barangay'),
                        controller: barangayController,
                        decoration: InputDecoration(
                          labelText: 'Barangay',
                          errorText: viewModel!.fieldError('barangay'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('address-city'),
                        controller: cityController,
                        validator: (value) =>
                            CustomerValidators.requiredText(value, 'City'),
                        decoration: InputDecoration(
                          labelText: 'City',
                          errorText: viewModel!.fieldError('city'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('address-province'),
                        controller: provinceController,
                        validator: (value) =>
                            CustomerValidators.requiredText(value, 'Province'),
                        decoration: InputDecoration(
                          labelText: 'Province',
                          errorText: viewModel!.fieldError('province'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('address-postal'),
                        controller: postalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Postal code (optional)',
                          errorText: viewModel!.fieldError('postal_code'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('address-notes'),
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Delivery notes (optional)',
                          hintText: 'Landmark, gate color, or instructions',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (viewModel!.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AuthErrorBanner(errorMessage: viewModel!.errorMessage),
              ),
            BottomAction(
              label: viewModel!.isSubmitting
                  ? 'Saving address…'
                  : widget.editing
                  ? 'Save changes'
                  : 'Save delivery address',
              enabled: !viewModel!.isSubmitting,
              onTap: submit,
            ),
          ],
        ),
      ),
    ),
  );
}

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  late CustomerAddressRepository repository;
  late Future<List<CustomerAddress>> future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    repository = CustomerDependencyScope.of(context).addressRepository;
    future = repository.list();
  }

  void reload() => setState(() {
    future = repository.list();
  });

  CustomerAddressRequest requestFor(
    CustomerAddress address, {
    bool? isDefault,
  }) => CustomerAddressRequest(
    label: address.label,
    recipientName: address.recipientName,
    phone: address.phone,
    addressLine: address.addressLine,
    barangay: address.barangay,
    city: address.city,
    province: address.province,
    postalCode: address.postalCode,
    latitude: address.latitude,
    longitude: address.longitude,
    notes: address.notes,
    isDefault: isDefault ?? address.isDefault,
  );

  Future<void> edit(CustomerAddress address) async {
    await Navigator.pushNamed(
      context,
      CustomerRoutes.addressSetup,
      arguments: CustomerAddressRouteArgs(address: address),
    );
    if (mounted) reload();
  }

  Future<void> makeDefault(CustomerAddress address) async {
    try {
      await repository.update(address.id, requestFor(address, isDefault: true));
      if (!mounted) return;
      message(context, 'Default address updated.', kind: ToastKind.success);
      reload();
    } on CustomerApiException catch (error) {
      if (mounted) message(context, error.message, kind: ToastKind.error);
    }
  }

  Future<void> remove(CustomerAddress address, int count) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${address.label ?? 'address'}?',
      body: 'This delivery address will be removed from your account.',
      confirmLabel: 'Delete address',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await repository.delete(address.id);
      if (!mounted) return;
      message(context, 'Address deleted.', kind: ToastKind.success);
      if (count == 1) {
        CustomerRouteScope.of(context).session.hasDeliveryAddress = false;
        Navigator.of(context).pushNamedAndRemoveUntil(
          CustomerRoutes.addressSetup,
          (_) => false,
          arguments: const CustomerAddressRouteArgs(firstRun: true),
        );
      } else {
        reload();
      }
    } on CustomerApiException catch (error) {
      if (mounted) message(context, error.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: simpleBar('My addresses'),
    body: FutureBuilder<List<CustomerAddress>>(
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
        final addresses = snapshot.data ?? const [];
        if (addresses.isEmpty) {
          return const EmptyState(
            icon: Icons.location_off_outlined,
            title: 'No saved addresses',
            subtitle: 'Add a delivery address to continue.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return AddressCard(
                label: address.label ?? 'Address',
                address: address.formatted,
                selected: address.isDefault,
                onDefault: address.isDefault
                    ? () {}
                    : () => makeDefault(address),
                onEdit: () => edit(address),
                onDelete: () => remove(address, addresses.length),
              );
            },
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.pushNamed(
          context,
          CustomerRoutes.addressSetup,
          arguments: const CustomerAddressRouteArgs(),
        );
        if (mounted) reload();
      },
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add address'),
    ),
  );
}
