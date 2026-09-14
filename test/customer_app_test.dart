import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tala_delivery_customer/customer_app.dart';

void main() {
  testWidgets('customer can place and track a static store order', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TalaCustomerApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'login layout');

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Where should we deliver?'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'address layout');

    await tester.tap(find.text('Save delivery address'));
    await tester.pumpAndSettle();
    expect(find.text('Nearby stores'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'home layout');

    await tester.tap(find.text('ABC Mini Mart'));
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'store layout');

    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View cart • 1 item'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'cart layout');

    await tester.tap(find.textContaining('Checkout •'));
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
    expect(find.text('Finding your rider…'), findsOneWidget);
    expect(find.byType(OrderTrackingPage), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'tracking layout');
  });
}
