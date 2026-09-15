import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tala_delivery_customer/customer/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'theme preference restores and persists light, dark, and system',
    () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.preferenceKey: ThemeMode.dark.name,
      });

      final controller = await ThemeController.restore();
      expect(controller.mode, ThemeMode.dark);

      await controller.setMode(ThemeMode.light);
      expect(controller.mode, ThemeMode.light);
      expect(
        (await SharedPreferences.getInstance()).getString(
          ThemeController.preferenceKey,
        ),
        ThemeMode.light.name,
      );

      await controller.setMode(ThemeMode.system);
      expect((await ThemeController.restore()).mode, ThemeMode.system);
    },
  );

  test('light and dark themes expose the matching brightness and palettes', () {
    final lightTheme = buildAppTheme(AppPalette.light);
    final darkTheme = buildAppTheme(AppPalette.dark);

    expect(lightTheme.brightness, Brightness.light);
    expect(darkTheme.brightness, Brightness.dark);
    expect(
      lightTheme.extension<AppPalette>()?.background,
      AppPalette.light.background,
    );
    expect(
      darkTheme.extension<AppPalette>()?.background,
      AppPalette.dark.background,
    );
  });
}
