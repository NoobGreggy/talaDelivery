part of '../../app.dart';

enum RiderUserRole { customer, rider }

class RiderSession {
  RiderSession({
    this.isRestoring = true,
    this.isAuthenticated = false,
    this.role,
    this.isOnline = false,
    this.hasActiveDelivery = false,
    this.deliveryCompleted = false,
  });

  bool isRestoring;
  bool isAuthenticated;
  RiderUserRole? role;
  bool isOnline;
  bool hasActiveDelivery;
  bool deliveryCompleted;
}

class RiderRoutes {
  const RiderRoutes._();

  static const splash = '/';
  static const login = '/auth/login';
  static const dashboard = '/dashboard';
  static const offer = '/offers/current';
  static const activeDelivery = '/deliveries/active';
  static const deliveryComplete = '/deliveries/complete';
  static const history = '/history';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const accessDenied = '/access-denied';
  static const notFound = '/not-found';

  static const known = {
    splash,
    login,
    dashboard,
    offer,
    activeDelivery,
    deliveryComplete,
    history,
    profile,
    notifications,
    accessDenied,
    notFound,
  };
}

class RiderRouteScope extends InheritedWidget {
  const RiderRouteScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final RiderRouteController controller;

  static RiderRouteController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RiderRouteScope>();
    assert(scope != null, 'RiderRouteScope is missing above this context.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(RiderRouteScope oldWidget) =>
      controller != oldWidget.controller;
}

class RiderRouteController {
  RiderRouteController(this.session);

  final RiderSession session;
  RouteSettings? _pendingRoute;

  void finishRestoring() => session.isRestoring = false;

  void signInAsRider() {
    session
      ..isRestoring = false
      ..isAuthenticated = true
      ..role = RiderUserRole.rider;
  }

  void sync(RiderAppController controller) {
    session
      ..isOnline = controller.profile?.isOnline ?? false
      ..hasActiveDelivery = controller.activeDelivery != null;
  }

  void setOnline(bool value) => session.isOnline = value;

  void startDelivery() {
    session
      ..hasActiveDelivery = true
      ..deliveryCompleted = false;
  }

  void completeDelivery() {
    session
      ..hasActiveDelivery = false
      ..deliveryCompleted = true;
  }

  void finishDelivery() {
    session
      ..deliveryCompleted = false
      ..isOnline = true;
  }

  void signOut() {
    session
      ..isAuthenticated = false
      ..role = null
      ..isOnline = false
      ..hasActiveDelivery = false
      ..deliveryCompleted = false;
    _pendingRoute = null;
  }

  RouteSettings destinationAfterSignIn() {
    if (session.role != RiderUserRole.rider) {
      return const RouteSettings(name: RiderRoutes.accessDenied);
    }
    final destination = _pendingRoute;
    _pendingRoute = null;
    return destination ?? const RouteSettings(name: RiderRoutes.dashboard);
  }

  String guardLocation(String? requestedName, {Object? arguments}) {
    final requested = requestedName ?? RiderRoutes.splash;
    if (!RiderRoutes.known.contains(requested)) return RiderRoutes.notFound;
    if (requested == RiderRoutes.splash ||
        requested == RiderRoutes.notFound ||
        requested == RiderRoutes.accessDenied) {
      return requested;
    }
    if (session.isRestoring) return RiderRoutes.splash;
    if (requested == RiderRoutes.login) {
      if (!session.isAuthenticated) return requested;
      return session.role == RiderUserRole.rider
          ? RiderRoutes.dashboard
          : RiderRoutes.accessDenied;
    }
    if (!session.isAuthenticated) {
      _pendingRoute = RouteSettings(name: requested, arguments: arguments);
      return RiderRoutes.login;
    }
    if (session.role != RiderUserRole.rider) {
      return RiderRoutes.accessDenied;
    }
    if (requested == RiderRoutes.offer && !session.isOnline) {
      return RiderRoutes.dashboard;
    }
    if (requested == RiderRoutes.activeDelivery && !session.hasActiveDelivery) {
      return RiderRoutes.dashboard;
    }
    if (requested == RiderRoutes.deliveryComplete &&
        !session.deliveryCompleted) {
      return session.hasActiveDelivery
          ? RiderRoutes.activeDelivery
          : RiderRoutes.dashboard;
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
    return MaterialPageRoute<dynamic>(
      settings: guardedSettings,
      builder: (_) => _pageFor(guardedSettings),
    );
  }

  Widget _pageFor(RouteSettings settings) {
    switch (settings.name) {
      case RiderRoutes.splash:
        return const SplashScreen();
      case RiderRoutes.login:
        return const LoginScreen();
      case RiderRoutes.dashboard:
        return const RiderShell();
      case RiderRoutes.history:
        return const RiderShell(initialTab: 1);
      case RiderRoutes.profile:
        return const RiderShell(initialTab: 2);
      case RiderRoutes.offer:
        return OfferScreen(offer: settings.arguments as RiderOffer?);
      case RiderRoutes.activeDelivery:
        return ActiveDeliveryScreen(
          delivery: settings.arguments as RiderDelivery?,
        );
      case RiderRoutes.deliveryComplete:
        return DeliveryCompleteScreen(
          delivery: settings.arguments as RiderDelivery?,
        );
      case RiderRoutes.notifications:
        return const NotificationsScreen();
      case RiderRoutes.accessDenied:
        return const RiderRouteErrorPage(
          title: 'Rider access required',
          message: 'This account cannot access the rider application.',
        );
      case RiderRoutes.notFound:
      default:
        return const RiderRouteErrorPage(
          title: 'Page not found',
          message: 'The requested rider page does not exist.',
        );
    }
  }
}

class RiderRouteErrorPage extends StatelessWidget {
  const RiderRouteErrorPage({
    super.key,
    required this.title,
    required this.message,
  });

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
            const Icon(Icons.lock_outline_rounded, color: blue, size: 54),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Go to login',
              onPressed: () {
                RiderRouteScope.of(context).signOut();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(RiderRoutes.login, (_) => false);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
