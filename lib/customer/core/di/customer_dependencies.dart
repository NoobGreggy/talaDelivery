part of '../../app.dart';

class CustomerAppDependencies {
  CustomerAppDependencies(
    this.authRepository,
    this.addressRepository,
    this.catalogRepository,
    this.orderRepository,
    this.notificationRepository,
    this.cartController, [
    this._ownedClient,
  ]);

  factory CustomerAppDependencies.live({CustomerApiConfig? config}) {
    final client = http.Client();
    final tokenStore = MemoryCustomerTokenStore();
    final apiClient = CustomerApiClient(
      client,
      config ?? CustomerApiConfig.fromEnvironment(),
      tokenStore,
    );
    return CustomerAppDependencies(
      ApiCustomerAuthRepository(apiClient, tokenStore),
      ApiCustomerAddressRepository(apiClient),
      ApiCustomerCatalogRepository(apiClient),
      ApiCustomerOrderRepository(apiClient),
      ApiCustomerNotificationRepository(apiClient),
      CustomerCartController(),
      client,
    );
  }

  final CustomerAuthRepository authRepository;
  final CustomerAddressRepository addressRepository;
  final CustomerCatalogRepository catalogRepository;
  final CustomerOrderRepository orderRepository;
  final CustomerNotificationRepository notificationRepository;
  final CustomerCartController cartController;
  final http.Client? _ownedClient;

  void dispose() {
    cartController.dispose();
    _ownedClient?.close();
  }
}

class CustomerDependencyScope extends InheritedWidget {
  const CustomerDependencyScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final CustomerAppDependencies dependencies;

  static CustomerAppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<CustomerDependencyScope>();
    assert(scope != null, 'CustomerDependencyScope is missing.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(CustomerDependencyScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
