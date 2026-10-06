import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show
        ValueListenable,
        ValueNotifier,
        kDebugMode,
        kProfileMode,
        defaultTargetPlatform,
        TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'core/config/rider_api_config.dart';
import 'core/config/rider_map_config.dart';
import 'shared/models/delivery_stage.dart';
import 'shared/theme/theme.dart';

export 'core/config/rider_api_config.dart';
export 'core/config/rider_map_config.dart';
export 'shared/models/delivery_stage.dart';
export 'shared/theme/theme.dart';

part 'core/network/rider_api_client.dart';
part 'core/realtime/rider_realtime_service.dart';
part 'core/location/rider_location_service.dart';
part 'core/navigation/rider_navigation.dart';
part 'core/di/rider_dependencies.dart';
part 'data/rider_repository.dart';
part 'shared/models/rider_wallet.dart';
part 'logic/rider_wallet_controller.dart';
part 'features/wallet/rider_wallet_screen.dart';
part 'logic/rider_app_controller.dart';
part 'logic/rider_shift_lifecycle.dart';
part 'shared/models/rider_models.dart';
part 'shared/widgets/rider_widgets.dart';
part 'core/routing/rider_router.dart';
part 'features/auth/rider_auth_screens.dart';
part 'features/dashboard/rider_dashboard_screen.dart';
part 'features/offers/rider_offer_screen.dart';
part 'features/searching/rider_searching_screen.dart';
part 'features/deliveries/rider_delivery_screens.dart';
part 'features/deliveries/widgets/rider_delivery_map.dart';
part 'features/history/rider_history_screen.dart';
part 'features/notifications/rider_notifications_screen.dart';
part 'features/profile/rider_profile_screen.dart';

/// Distance-bounded timing telemetry for the performance plan. Enabled only in
/// debug/profile builds and compiled out of release. Logs never include
/// tokens, API keys, addresses, or precise coordinates.
const bool riderPerfTelemetry = kDebugMode || kProfileMode;

/// Opt-in performance overlay: `flutter run --dart-define=TALA_PERF_OVERLAY=true`.
/// Never renders in release builds regardless of the define.
const bool riderPerfOverlayEnabled =
    bool.fromEnvironment('TALA_PERF_OVERLAY') && (kDebugMode || kProfileMode);

void _riderPerfTrace(String label, DateTime startedAt) {
  if (riderPerfTelemetry) {
    debugPrint(
      'TalaPerf: $label in '
      '${DateTime.now().difference(startedAt).inMilliseconds}ms',
    );
  }
}

void _riderPerfEvent(String label) {
  if (riderPerfTelemetry) debugPrint('TalaPerf: $label');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mapConfig = RiderMapConfig.fromEnvironment();
  if (mapConfig.isConfigured) {
    mapbox.MapboxOptions.setAccessToken(mapConfig.accessToken);
  }
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
    } else if (state == AppLifecycleState.paused) {
      dependencies.controller.handleAppPaused();
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
              builder: (context, child) {
                if (!riderPerfOverlayEnabled) {
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
  RiderAppController? _controller;
  RiderRouteController? _routes;
  late final List<_RiderPage> _pages = _buildPages();

  List<_RiderPage> _buildPages() => [
    _RiderPage(
      selector: _dashboardSelector,
      builder: (context, controller) => DashboardScreen(
        controller: controller,
        onEarnings: () => setState(() => tab = 1),
      ),
    ),
    _RiderPage(
      selector: _historySelector,
      builder: (context, controller) => HistoryScreen(controller: controller),
    ),
    _RiderPage(
      selector: _profileSelector,
      builder: (context, controller) => ProfileScreen(controller: controller),
    ),
  ];

  static Object? _dashboardSelector(RiderAppController controller) => (
    controller.user,
    controller.profile,
    controller.offers,
    controller.activeDelivery,
    controller.earningsSummary,
    controller.isLoading,
    controller.isSubmitting,
    controller.unreadNotificationCount,
    controller.errorMessage,
  );

  static Object? _historySelector(RiderAppController controller) => (
    controller.user,
    controller.deliveries,
    controller.earningsSummary,
    controller.isLoading,
    controller.errorMessage,
  );

  static Object? _profileSelector(RiderAppController controller) => (
    controller.user,
    controller.profile,
    controller.isLoading,
    controller.errorMessage,
  );

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = RiderDependencyScope.of(context).controller;
    final routes = RiderRouteScope.of(context);
    if (_controller != controller) {
      _controller?.removeListener(_syncRoutes);
      _controller = controller;
      _controller?.addListener(_syncRoutes);
    }
    _routes = routes;
    _syncRoutes();
  }

  void _syncRoutes() {
    final controller = _controller;
    final routes = _routes;
    if (controller == null || routes == null || !mounted) return;
    routes.sync(controller);
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncRoutes);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tab, children: _pages),
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
  }
}

/// Runs a single page inside its own controller listener so one controller
/// notification does not rebuild the whole shell, the navigation bar, or every
/// tab. An optional [selector] narrows rebuilds to the page's relevant state.
class _RiderPage extends StatefulWidget {
  const _RiderPage({required this.selector, required this.builder});

  final Object? Function(RiderAppController controller)? selector;
  final Widget Function(BuildContext context, RiderAppController controller)
  builder;

  @override
  State<_RiderPage> createState() => _RiderPageState();
}

class _RiderPageState extends State<_RiderPage> {
  RiderAppController? _controller;
  Object? _last;
  bool usedSelector = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = RiderDependencyScope.of(context).controller;
    if (_controller == controller) return;
    _controller?.removeListener(_onControllerChanged);
    _controller = controller;
    _last = widget.selector?.call(controller);
    usedSelector = widget.selector != null;
    _controller?.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final selector = widget.selector;
    if (selector == null) {
      setState(() {});
      return;
    }
    final current = selector(_controller!);
    if (usedSelector && current == _last) return;
    _last = current;
    usedSelector = true;
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller!);
  }
}
