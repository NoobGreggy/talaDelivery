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
    testWidgets(
      'login brand stays top-left above the full-width form at $size',
      (tester) async {
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

        final logo = tester.getRect(find.byKey(const Key('login-brand-logo')));
        final brand = tester.getRect(find.text('TalaDelivery'));
        final tagline = tester.getRect(find.text('Delivered by starlight'));
        final form = tester.getRect(find.byType(Form).first);

        expect(logo.left, closeTo(24, 1));
        expect(logo.bottom, lessThanOrEqualTo(brand.top));
        expect(tagline.top, greaterThan(brand.bottom));
        expect(tagline.bottom, lessThanOrEqualTo(form.top));
        expect(find.byIcon(Icons.star_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
