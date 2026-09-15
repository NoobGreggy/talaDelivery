import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
  test('rider theme restores light, dark, and system choices', () async {
    SharedPreferences.setMockInitialValues({
      RiderThemeController.preferenceKey: 'dark',
    });
    final controller = await RiderThemeController.restore();
    expect(controller.mode, ThemeMode.dark);

    await controller.setMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);

    await controller.setMode(ThemeMode.system);
    expect(controller.mode, ThemeMode.system);
    expect(
      (await SharedPreferences.getInstance()).getString(
        RiderThemeController.preferenceKey,
      ),
      'system',
    );
  });
}
