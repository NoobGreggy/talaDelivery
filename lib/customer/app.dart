import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'core/config/customer_api_config.dart';
import 'core/config/customer_map_config.dart';
import 'features/auth/logic/auth_validators.dart';
import 'shared/theme/theme.dart';

export 'core/config/customer_api_config.dart';
export 'core/config/customer_map_config.dart';
export 'features/auth/logic/auth_validators.dart';
export 'shared/theme/theme.dart';

part 'core/di/customer_dependencies.dart';
part 'core/location/customer_location_service.dart';
part 'core/network/customer_api_client.dart';
part 'core/realtime/customer_realtime.dart';
part 'shared/models/catalog_models.dart';
part 'shared/models/geo_models.dart';
part 'shared/widgets/ui_widgets.dart';
part 'shared/widgets/catalog_widgets.dart';
part 'shared/widgets/feedback_widgets.dart';
part 'shared/widgets/tala_widgets.dart';
part 'shared/widgets/dusk_widgets.dart';
part 'core/routing/customer_router.dart';
part 'features/catalog/data/catalog_repository.dart';
part 'features/cart/logic/cart_controller.dart';
part 'features/auth/data/auth_models.dart';
part 'features/auth/data/auth_repository.dart';
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
part 'features/orders/widgets/customer_delivery_map.dart';
part 'features/addresses/data/address_models.dart';
part 'features/addresses/data/address_repository.dart';
part 'features/addresses/data/customer_reverse_geocoder.dart';
part 'features/addresses/view_models/address_view_model.dart';
part 'features/addresses/address_screens.dart';
part 'features/addresses/widgets/customer_address_map_picker.dart';
part 'features/profile/profile_screen.dart';
part 'features/profile/edit_profile_screen.dart';
part 'features/profile/view_models/customer_profile_view_model.dart';
part 'core/notifications/data/notification_models.dart';
part 'core/notifications/data/notification_repository.dart';
part 'core/notifications/notifications_screen.dart';

/// Distance-bounded timing telemetry for the performance plan. Enabled only in
/// debug/profile builds and compiled out of release. Logs never include
/// tokens, API keys, addresses, or precise coordinates.
const bool customerPerfTelemetry = kDebugMode || kProfileMode;

/// Opt-in performance overlay: `flutter run --dart-define=TALA_PERF_OVERLAY=true`.
/// Never renders in release builds regardless of the define.
const bool customerPerfOverlayEnabled =
    bool.fromEnvironment('TALA_PERF_OVERLAY') && (kDebugMode || kProfileMode);

void _customerPerfTrace(String label, DateTime startedAt) {
  if (customerPerfTelemetry) {
    debugPrint(
      'TalaPerf: $label in '
      '${DateTime.now().difference(startedAt).inMilliseconds}ms',
    );
  }
}

void _customerPerfEvent(String label) {
  if (customerPerfTelemetry) debugPrint('TalaPerf: $label');
}

/// Reduces a store-hour value to "HH:mm". The backend may send a full
/// timestamp ("2026-09-28T08:00:00.000Z"), "2026-09-28 08:00:00", or a bare
/// "08:00:00"/"08:00"; the date part is never shown.
String _talaShortHour(String value) {
  final time = DateTime.tryParse(value);
  if (time != null) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  final parts = value.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
}

/// Trailing clearance a scrollable needs so its last container is never hidden
/// behind the floating bottom navigation. The customer shell uses
/// `extendBody`, so content would otherwise end underneath the floating bar.
double _customerScrollClearance(BuildContext context) {
  const navHeight = 68.0;
  const navBottomMargin = 12.0;
  const breathingRoom = 16.0;
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  return navHeight + math.max(bottomInset, navBottomMargin) + breathingRoom;
}

Future<TalaCustomerApp> createCustomerApp({
  CustomerAppDependencies? dependencies,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final mapConfig = CustomerMapConfig.fromEnvironment();
  if (mapConfig.isConfigured) {
    mapbox.MapboxOptions.setAccessToken(mapConfig.accessToken);
  }
  final themeController = await ThemeController.restore();
  return TalaCustomerApp(
    themeController: themeController,
    dependencies: dependencies,
  );
}

Future<void> main() async => runApp(await createCustomerApp());

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
              builder: (context, child) {
                if (!customerPerfOverlayEnabled) {
                  return child ?? const SizedBox.shrink();
                }
                return Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    const Positioned.fill(
                      child: IgnorePointer(child: PerformanceOverlay()),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
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
    const pages = [
      HomePage(),
      SafeArea(bottom: false, child: OrdersPage()),
      SafeArea(bottom: false, child: ProfilePage()),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: TalaCustomerBottomNav(
        selectedIndex: tab,
        onHome: () => setState(() => tab = 0),
        onOrders: () => setState(() => tab = 1),
        onSaved: () => message(context, 'Saved stores are coming soon.'),
        onAccount: () => setState(() => tab = 2),
      ),
    );
  }
}
