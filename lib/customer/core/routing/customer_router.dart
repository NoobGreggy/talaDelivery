part of '../../app.dart';

enum CustomerUserRole { customer, rider }

class CustomerSession {
  CustomerSession({
    this.isRestoring = true,
    this.isAuthenticated = false,
    this.role,
    this.hasDeliveryAddress = false,
    this.user,
  });

  bool isRestoring;
  bool isAuthenticated;
  CustomerUserRole? role;
  bool hasDeliveryAddress;
  CustomerUser? user;
}

class CustomerRoutes {
  const CustomerRoutes._();

  static const splash = '/';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const addressSetup = '/address/setup';
  static const home = '/home';
  static const stores = '/stores';
  static const storeDetails = '/stores/details';
  static const productDetails = '/products/details';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const orderSuccess = '/orders/success';
  static const orderTracking = '/orders/tracking';
  static const addresses = '/addresses';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const accessDenied = '/access-denied';
  static const notFound = '/not-found';

  static const known = {
    splash,
    login,
    register,
    forgotPassword,
    addressSetup,
    home,
    stores,
    storeDetails,
    productDetails,
    cart,
    checkout,
    orders,
    orderSuccess,
    orderTracking,
    addresses,
    notifications,
    profile,
    accessDenied,
    notFound,
  };
}

class CustomerAddressRouteArgs {
  const CustomerAddressRouteArgs({this.firstRun = false, this.address});

  final bool firstRun;
  final CustomerAddress? address;
}

class CustomerStoreListingRouteArgs {
  const CustomerStoreListingRouteArgs({
    this.initialSearch = '',
    this.initialFilter = 0,
  });

  final String initialSearch;
  final int initialFilter;
}

class CustomerRouteScope extends InheritedWidget {
  const CustomerRouteScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final CustomerRouteController controller;

  static CustomerRouteController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<CustomerRouteScope>();
    assert(scope != null, 'CustomerRouteScope is missing above this context.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(CustomerRouteScope oldWidget) =>
      controller != oldWidget.controller;
}

class CustomerRouteController {
  CustomerRouteController(this.session);

  final CustomerSession session;
  RouteSettings? _pendingRoute;

  static const _authRoutes = {
    CustomerRoutes.login,
    CustomerRoutes.register,
    CustomerRoutes.forgotPassword,
  };

  static const _requiresAddress = {
    CustomerRoutes.home,
    CustomerRoutes.stores,
    CustomerRoutes.storeDetails,
    CustomerRoutes.productDetails,
    CustomerRoutes.cart,
    CustomerRoutes.checkout,
    CustomerRoutes.orders,
    CustomerRoutes.orderSuccess,
    CustomerRoutes.orderTracking,
    CustomerRoutes.addresses,
    CustomerRoutes.notifications,
    CustomerRoutes.profile,
  };

  void finishRestoring() => session.isRestoring = false;

  void signInAsCustomer() {
    signInWithRole('customer');
  }

  void signInWithRole(String role, {bool hasDeliveryAddress = false}) {
    session
      ..isRestoring = false
      ..isAuthenticated = true
      ..role = switch (role) {
        'customer' => CustomerUserRole.customer,
        'rider' => CustomerUserRole.rider,
        _ => null,
      }
      ..hasDeliveryAddress = hasDeliveryAddress;
  }

  void signInWithUser(CustomerUser user, {bool hasDeliveryAddress = false}) {
    signInWithRole(user.role, hasDeliveryAddress: hasDeliveryAddress);
    session.user = user;
  }

  void completeAddressSetup() => session.hasDeliveryAddress = true;

  void signOut() {
    session
      ..isAuthenticated = false
      ..role = null
      ..hasDeliveryAddress = false
      ..user = null;
    _pendingRoute = null;
  }

  RouteSettings destinationAfterSignIn() {
    if (session.role != CustomerUserRole.customer) {
      return const RouteSettings(name: CustomerRoutes.accessDenied);
    }
    if (!session.hasDeliveryAddress) {
      return const RouteSettings(
        name: CustomerRoutes.addressSetup,
        arguments: CustomerAddressRouteArgs(firstRun: true),
      );
    }
    return _takePendingRoute();
  }

  RouteSettings destinationAfterAddressSetup() => _takePendingRoute();

  RouteSettings _takePendingRoute() {
    final destination = _pendingRoute;
    _pendingRoute = null;
    return destination ?? const RouteSettings(name: CustomerRoutes.home);
  }

  String guardLocation(String? requestedName, {Object? arguments}) {
    final requested = requestedName ?? CustomerRoutes.splash;
    if (!CustomerRoutes.known.contains(requested)) {
      return CustomerRoutes.notFound;
    }
    if (requested == CustomerRoutes.splash ||
        requested == CustomerRoutes.notFound ||
        requested == CustomerRoutes.accessDenied) {
      return requested;
    }
    if (session.isRestoring) return CustomerRoutes.splash;
    if (_authRoutes.contains(requested)) {
      if (!session.isAuthenticated) return requested;
      if (session.role != CustomerUserRole.customer) {
        return CustomerRoutes.accessDenied;
      }
      return session.hasDeliveryAddress
          ? CustomerRoutes.home
          : CustomerRoutes.addressSetup;
    }
    if (!session.isAuthenticated) {
      _pendingRoute = RouteSettings(name: requested, arguments: arguments);
      return CustomerRoutes.login;
    }
    if (session.role != CustomerUserRole.customer) {
      return CustomerRoutes.accessDenied;
    }
    if (_requiresAddress.contains(requested) && !session.hasDeliveryAddress) {
      _pendingRoute = RouteSettings(name: requested, arguments: arguments);
      return CustomerRoutes.addressSetup;
    }
    return requested;
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final guardedName = guardLocation(
      settings.name,
      arguments: settings.arguments,
    );
    final guardedSettings = RouteSettings(
      name: guardedName,
      arguments: guardedName == settings.name ? settings.arguments : null,
    );
    final page = _pageFor(guardedSettings);
    return MaterialPageRoute<dynamic>(
      settings: guardedSettings,
      builder: (_) => page,
    );
  }

  Widget _pageFor(RouteSettings settings) {
    switch (settings.name) {
      case CustomerRoutes.splash:
        return const CustomerSplash();
      case CustomerRoutes.login:
        return const LoginPage();
      case CustomerRoutes.register:
        return const RegisterPage();
      case CustomerRoutes.forgotPassword:
        return const ForgotPasswordPage();
      case CustomerRoutes.addressSetup:
        final args = settings.arguments is CustomerAddressRouteArgs
            ? settings.arguments! as CustomerAddressRouteArgs
            : const CustomerAddressRouteArgs(firstRun: true);
        return AddressSetupPage(firstRun: args.firstRun, address: args.address);
      case CustomerRoutes.home:
        return const CustomerShell();
      case CustomerRoutes.orders:
        return const CustomerShell(initialTab: 1);
      case CustomerRoutes.profile:
        return const CustomerShell(initialTab: 2);
      case CustomerRoutes.stores:
        final args = switch (settings.arguments) {
          CustomerStoreListingRouteArgs args => args,
          int initialFilter => CustomerStoreListingRouteArgs(
            initialFilter: initialFilter,
          ),
          _ => const CustomerStoreListingRouteArgs(),
        };
        return StoreListingPage(
          initialSearch: args.initialSearch,
          initialFilter: args.initialFilter,
        );
      case CustomerRoutes.storeDetails:
        if (settings.arguments is StoreData) {
          return StoreDetailPage(store: settings.arguments! as StoreData);
        }
        return const RouteErrorPage(
          title: 'Store unavailable',
          message: 'This route requires a valid store.',
        );
      case CustomerRoutes.productDetails:
        if (settings.arguments is ProductData) {
          return ProductDetailPage(product: settings.arguments! as ProductData);
        }
        return const RouteErrorPage(
          title: 'Product unavailable',
          message: 'This route requires a valid product.',
        );
      case CustomerRoutes.cart:
        return const CartPage();
      case CustomerRoutes.checkout:
        return const CheckoutPage();
      case CustomerRoutes.orderSuccess:
        if (settings.arguments is CustomerOrder) {
          return OrderSuccessPage(order: settings.arguments! as CustomerOrder);
        }
        return const RouteErrorPage(
          title: 'Order unavailable',
          message: 'The completed order could not be loaded.',
        );
      case CustomerRoutes.orderTracking:
        if (settings.arguments is CustomerOrder) {
          return OrderTrackingPage(order: settings.arguments! as CustomerOrder);
        }
        if (settings.arguments is int) {
          return OrderTrackingPage(orderId: settings.arguments! as int);
        }
        return const RouteErrorPage(
          title: 'Order unavailable',
          message: 'Choose an order from your order history.',
        );
      case CustomerRoutes.addresses:
        return const AddressesPage();
      case CustomerRoutes.notifications:
        return const NotificationsPage();
      case CustomerRoutes.accessDenied:
        return const RouteErrorPage(
          title: 'Customer access required',
          message: 'This account cannot access the customer application.',
        );
      case CustomerRoutes.notFound:
      default:
        return const RouteErrorPage(
          title: 'Page not found',
          message: 'The requested customer page does not exist.',
        );
    }
  }
}

class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, color: sky, size: 54),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            PrimaryAction(
              label: 'Go to login',
              onTap: () {
                CustomerRouteScope.of(context).signOut();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(CustomerRoutes.login, (_) => false);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
