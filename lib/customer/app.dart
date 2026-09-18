import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'core/config/customer_api_config.dart';
part 'core/di/customer_dependencies.dart';
part 'core/network/customer_api_client.dart';
part 'core/realtime/customer_realtime.dart';
part 'shared/theme/theme.dart';
part 'shared/models/catalog_models.dart';
part 'shared/widgets/ui_widgets.dart';
part 'core/routing/customer_router.dart';
part 'features/catalog/data/catalog_repository.dart';
part 'features/cart/logic/cart_controller.dart';
part 'features/auth/data/auth_models.dart';
part 'features/auth/data/auth_repository.dart';
part 'features/auth/logic/auth_validators.dart';
part 'features/auth/view_models/auth_view_model.dart';
part 'features/auth/auth_screens.dart';
part 'features/home/home_screen.dart';
part 'features/stores/store_screens.dart';
part 'features/products/product_screen.dart';
part 'features/cart/cart_screen.dart';
part 'features/checkout/checkout_screen.dart';
part 'features/orders/order_screens.dart';
part 'features/orders/data/order_models.dart';
part 'features/orders/data/order_repository.dart';
part 'features/addresses/data/address_models.dart';
part 'features/addresses/data/address_repository.dart';
part 'features/addresses/view_models/address_view_model.dart';
part 'features/addresses/address_screens.dart';
part 'features/profile/profile_screen.dart';
part 'features/profile/edit_profile_screen.dart';
part 'features/profile/view_models/customer_profile_view_model.dart';
part 'core/notifications/data/notification_models.dart';
part 'core/notifications/data/notification_repository.dart';
part 'core/notifications/notifications_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.restore();
  runApp(TalaCustomerApp(themeController: themeController));
}

class TalaCustomerApp extends StatefulWidget {
  const TalaCustomerApp({
    super.key,
    this.onContinueAsRider,
    this.session,
    this.dependencies,
    this.themeController,
    this.initialThemeMode = ThemeMode.system,
  });

  final VoidCallback? onContinueAsRider;
  final CustomerSession? session;
  final CustomerAppDependencies? dependencies;
  final ThemeController? themeController;
  final ThemeMode initialThemeMode;

  @override
  State<TalaCustomerApp> createState() => _TalaCustomerAppState();
}

class _TalaCustomerAppState extends State<TalaCustomerApp>
    with WidgetsBindingObserver {
  late final CustomerRouteController routes;
  late final CustomerAppDependencies dependencies;
  late final ThemeController themeController;

  @override
  void initState() {
    super.initState();
    dependencies = widget.dependencies ?? CustomerAppDependencies.live();
    WidgetsBinding.instance.addObserver(this);
    routes = CustomerRouteController(widget.session ?? CustomerSession());
    themeController =
        widget.themeController ?? ThemeController(widget.initialThemeMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.themeController == null) themeController.dispose();
    if (widget.dependencies == null) dependencies.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      dependencies.realtime.resume();
    } else if (state == AppLifecycleState.paused) {
      dependencies.realtime.pause();
    }
  }

  @override
  Widget build(BuildContext context) => RiderSwitchScope(
    onContinueAsRider: widget.onContinueAsRider,
    child: ThemeScope(
      controller: themeController,
      child: CustomerDependencyScope(
        dependencies: dependencies,
        child: CustomerRouteScope(
          controller: routes,
          child: ListenableBuilder(
            listenable: themeController,
            builder: (context, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'TalaDelivery',
              initialRoute: CustomerRoutes.splash,
              onGenerateRoute: routes.onGenerateRoute,
              themeMode: themeController.mode,
              theme: buildAppTheme(AppPalette.light),
              darkTheme: buildAppTheme(AppPalette.dark),
            ),
          ),
        ),
      ),
    ),
  );
}

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([
    super.value = ThemeMode.system,
    SharedPreferences? preferences,
  ]) : _preferences = preferences;

  static const preferenceKey = 'customer_theme_mode';

  final SharedPreferences? _preferences;

  static Future<ThemeController> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(preferenceKey);
    final mode = switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return ThemeController(mode, preferences);
  }

  ThemeMode get mode => value;
  set mode(ThemeMode next) => unawaited(setMode(next));

  Future<void> setMode(ThemeMode next) async {
    if (value == next) return;
    value = next;
    await _preferences?.setString(preferenceKey, next.name);
  }

  void cycle() {
    mode = switch (value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }
}

class ThemeScope extends InheritedWidget {
  const ThemeScope({super.key, required this.controller, required super.child});

  final ThemeController controller;

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope is missing above this context.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) =>
      controller != oldWidget.controller;
}

class RiderSwitchScope extends InheritedWidget {
  const RiderSwitchScope({
    super.key,
    required super.child,
    required this.onContinueAsRider,
  });

  final VoidCallback? onContinueAsRider;

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RiderSwitchScope>()
      ?.onContinueAsRider;

  @override
  bool updateShouldNotify(RiderSwitchScope oldWidget) =>
      onContinueAsRider != oldWidget.onContinueAsRider;
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int tab;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    const pages = [HomePage(), OrdersPage(), ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
