import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import 'rider/app.dart';

export 'rider/app.dart' hide main;

Future<void> main() => riderMain();

Future<void> riderMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mapConfig = RiderMapConfig.fromEnvironment();
  if (mapConfig.isConfigured) {
    mapbox.MapboxOptions.setAccessToken(mapConfig.accessToken);
  }
  final dependencies = await RiderAppDependencies.live();
  final theme = await RiderThemeController.restore();
  runApp(TalaDeliveryApp(dependencies: dependencies, themeController: theme));
}
