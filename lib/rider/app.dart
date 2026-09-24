import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'core/config/rider_api_config.dart';
import 'core/config/rider_map_config.dart';
import 'shared/theme/theme.dart';

export 'core/config/rider_api_config.dart';
export 'core/config/rider_map_config.dart';
export 'shared/models/delivery_stage.dart';
export 'shared/theme/theme.dart';

part 'core/network/rider_api_client.dart';
part 'core/realtime/rider_realtime_service.dart';
part 'core/location/rider_location_service.dart';
part 'core/di/rider_dependencies.dart';
part 'data/rider_repository.dart';
part 'logic/rider_app_controller.dart';
part 'logic/rider_shift_lifecycle.dart';
part 'shared/models/rider_models.dart';
part 'shared/widgets/rider_widgets.dart';
part 'core/routing/rider_router.dart';
part 'features/auth/rider_auth_screens.dart';
part 'features/dashboard/rider_dashboard_screen.dart';
part 'features/offers/rider_offer_screen.dart';
part 'features/deliveries/rider_delivery_screens.dart';
part 'features/deliveries/widgets/rider_delivery_map.dart';
part 'features/history/rider_history_screen.dart';
part 'features/notifications/rider_notifications_screen.dart';
part 'features/profile/rider_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await RiderAppDependencies.live();
  final theme = await RiderThemeController.restore();
  runApp(TalaDeliveryApp(dependencies: dependencies, themeController: theme));
}

class TalaDeliveryApp extends StatefulWidget {
  const TalaDeliveryApp({
    super.key,
    this.onContinueAsCustomer,
    this.session,
    this.dependencies,
    this.themeController,
    this.initialThemeMode = ThemeMode.system,
  });

  final VoidCallback? onContinueAsCustomer;
  final RiderSession? session;
  final RiderAppDependencies? dependencies;
  final RiderThemeController? themeController;
  final ThemeMode initialThemeMode;

  @override
  State<TalaDeliveryApp> createState() => _TalaDeliveryAppState();
}

class _TalaDeliveryAppState extends State<TalaDeliveryApp>
    with WidgetsBindingObserver {
  late final RiderRouteController routes;
  late final RiderAppDependencies dependencies;
  late final RiderThemeController themeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    routes = RiderRouteController(widget.session ?? RiderSession());
    dependencies = widget.dependencies ?? RiderAppDependencies.transient();
    themeController =
        widget.themeController ?? RiderThemeController(widget.initialThemeMode);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      dependencies.controller.handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dependencies.dispose();
    if (widget.themeController == null) themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomerSwitchScope(
    onContinueAsCustomer: widget.onContinueAsCustomer,
    child: RiderThemeScope(
      controller: themeController,
      child: RiderDependencyScope(
        dependencies: dependencies,
        child: RiderRouteScope(
          controller: routes,
          child: ListenableBuilder(
            listenable: themeController,
            builder: (context, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'TalaDelivery Rider',
              initialRoute: RiderRoutes.splash,
              onGenerateRoute: routes.onGenerateRoute,
              themeMode: themeController.mode,
              theme: buildRiderTheme(RiderPalette.light),
              darkTheme: buildRiderTheme(RiderPalette.dark),
            ),
          ),
        ),
      ),
    ),
  );
}

class CustomerSwitchScope extends InheritedWidget {
  const CustomerSwitchScope({
    super.key,
    required super.child,
    required this.onContinueAsCustomer,
  });

  final VoidCallback? onContinueAsCustomer;

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CustomerSwitchScope>()
      ?.onContinueAsCustomer;

  @override
  bool updateShouldNotify(CustomerSwitchScope oldWidget) =>
      onContinueAsCustomer != oldWidget.onContinueAsCustomer;
}

class RiderShell extends StatefulWidget {
  const RiderShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  late int tab;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final routes = RiderRouteScope.of(context);
    final controller = RiderDependencyScope.of(context).controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        routes.sync(controller);
        final pages = [
          DashboardScreen(
            controller: controller,
            onOffer: () => Navigator.of(context).pushNamed(
              RiderRoutes.offer,
              arguments: controller.offers.firstOrNull,
            ),
            onEarnings: () => setState(() => tab = 1),
          ),
          HistoryScreen(controller: controller),
          ProfileScreen(controller: controller),
        ];
        return Scaffold(
          body: IndexedStack(index: tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            height: 72,
            onDestinationSelected: (index) => setState(() => tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
