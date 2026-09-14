import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tala_delivery_rider/main.dart';

void main() {
  testWidgets('rider can complete the static delivery flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TalaDeliveryApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'login layout');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'dashboard layout');
    await tester.tap(find.text('Go online'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'online dashboard layout');
    await tester.tap(find.text('Demo delivery available'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'offer layout');
    expect(find.text('₱69 estimated earnings'), findsOneWidget);

    await tester.ensureVisible(find.text('Accept delivery'));
    await tester.tap(find.text('Accept delivery'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'active delivery layout');
    expect(find.text('Heading to pickup'), findsOneWidget);

    await tester.tap(find.text('I’ve arrived at store'));
    await tester.pumpAndSettle();
    expect(find.text('8392'), findsOneWidget);
    await tester.tap(find.text('Mark as picked up'));
    await tester.pumpAndSettle();
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    await tester.tap(find.text('Start delivery'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Received'));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Mark as delivered'));
    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();
    expect(find.text('Complete delivery?'), findsOneWidget);
    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery completed!'), findsOneWidget);
  });
}
