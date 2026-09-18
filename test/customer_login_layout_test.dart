import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/customer_app.dart';

import 'support/customer_fakes.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.3),
    (const Size(320, 640), 1.6),
  ]) {
    testWidgets('login headline stays centered above the form at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        TalaCustomerApp(dependencies: fakeCustomerDependencies()),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final headline = tester.getRect(
        find.text('Your deliveries are\none sign-in away.'),
      );
      final brand = tester.getRect(find.text('TalaDelivery'));
      final map = tester.getRect(find.byKey(const Key('login-map-preview')));
      final form = tester.getRect(find.byType(Form).first);

      expect((headline.center.dx - size.width / 2).abs(), lessThan(10));
      expect(headline.top, greaterThan(brand.bottom + 20));
      expect(map.top, greaterThan(headline.bottom + 10));
      expect(map.bottom, lessThan(form.top - 20));
      expect(
        find.descendant(
          of: find.byKey(const Key('login-map-preview')),
          matching: find.byIcon(Icons.location_on_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('FAST · SIMPLE · RELIABLE'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
