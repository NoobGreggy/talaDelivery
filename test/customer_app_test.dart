import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tala_delivery_customer/customer_app.dart';

import 'support/customer_fakes.dart';

void main() {
  testWidgets('customer can place and track an API-backed store order', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TalaCustomerApp(dependencies: fakeCustomerDependencies()),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'login layout');

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'customer@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'password123',
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Where should we deliver?'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'address layout');

    await tester.enterText(
      find.byKey(const Key('address-phone')),
      '09171234567',
    );
    await tester.enterText(
      find.byKey(const Key('address-line')),
      '123 Example Street',
    );
    await tester.enterText(
      find.byKey(const Key('address-city')),
      'Cabanatuan City',
    );
    await tester.enterText(
      find.byKey(const Key('address-province')),
      'Nueva Ecija',
    );
    await tester.tap(find.text('Save delivery address'));
    await tester.pumpAndSettle();
    expect(find.text('Available stores'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'home layout');

    await tester.tap(find.text('API Store'));
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'store layout');

    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View cart • 1 item'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'cart layout');

    await tester.tap(find.textContaining('Continue to checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'checkout layout');

    await tester.tap(find.textContaining('Place order •'));
    await tester.pumpAndSettle();
    expect(find.text('Place this order?'), findsOneWidget);
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();
    expect(find.text('Order placed!'), findsOneWidget);

    await tester.tap(find.text('Track order'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Order placed'), findsWidgets);
    expect(find.byType(OrderTrackingPage), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'tracking layout');
  });
}
