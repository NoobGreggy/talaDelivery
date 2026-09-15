import 'package:flutter/material.dart';

import 'rider/app.dart';

export 'rider/app.dart' hide main;

Future<void> main() => riderMain();

Future<void> riderMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await RiderAppDependencies.live();
  final theme = await RiderThemeController.restore();
  runApp(TalaDeliveryApp(dependencies: dependencies, themeController: theme));
}
