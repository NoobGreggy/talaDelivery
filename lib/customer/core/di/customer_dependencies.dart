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
    CustomerRealtimeController? realtime,
  ]) : realtime = realtime ?? CustomerRealtimeController();

  factory CustomerAppDependencies.live({CustomerApiConfig? config}) {
    final client = http.Client();
    final resolvedConfig = config ?? CustomerApiConfig.fromEnvironment();
    final tokenStore = SecureCustomerTokenStore(const FlutterSecureStorage());
    final apiClient = CustomerApiClient(client, resolvedConfig, tokenStore);
    return CustomerAppDependencies(
      ApiCustomerAuthRepository(apiClient, tokenStore),
      ApiCustomerAddressRepository(apiClient),
      ApiCustomerCatalogRepository(apiClient),
      ApiCustomerOrderRepository(apiClient),
      ApiCustomerNotificationRepository(apiClient),
      CustomerCartController(),
      client,
      CustomerRealtimeController(
        config: CustomerRealtimeConfig.fromEnvironment(resolvedConfig),
        tokenStore: tokenStore,
        authClient: client,
      ),
    );
  }

  final CustomerAuthRepository authRepository;
  final CustomerAddressRepository addressRepository;
  final CustomerCatalogRepository catalogRepository;
  final CustomerOrderRepository orderRepository;
  final CustomerNotificationRepository notificationRepository;
  final CustomerCartController cartController;
  final CustomerRealtimeController realtime;
  final http.Client? _ownedClient;

  void dispose() {
    realtime.dispose();
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
