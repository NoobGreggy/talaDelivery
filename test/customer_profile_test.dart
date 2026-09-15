import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/main.dart';

import 'support/customer_fakes.dart';

void main() {
  testWidgets('customer edits profile details and sees the updated account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeCustomerAuthRepository();
    final session = CustomerSession(
      isRestoring: false,
      isAuthenticated: true,
      role: CustomerUserRole.customer,
      hasDeliveryAddress: true,
      user: const CustomerUser(
        id: 1,
        name: 'Old Customer',
        email: 'old@example.com',
        phone: '09170000000',
        role: 'customer',
      ),
    );
    await tester.pumpWidget(
      TalaCustomerApp(
        session: session,
        dependencies: fakeCustomerDependencies(auth: auth),
      ),
    );
    await tester.pump();
    Navigator.of(tester.element(find.byType(CustomerSplash)))
        .pushReplacementNamed(CustomerRoutes.profile);
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    final nameField = find.byKey(const Key('profile-name'));
    final emailField = find.byKey(const Key('profile-email'));
    final phoneField = find.byKey(const Key('profile-phone'));
    expect(
      tester.widget<TextFormField>(nameField).controller!.text,
      'Old Customer',
    );

    await tester.enterText(nameField, 'Updated Customer');
    await tester.enterText(emailField, 'updated@example.com');
    await tester.enterText(phoneField, '09171234567');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(auth.updateProfileCalls, 1);
    expect(session.user?.name, 'Updated Customer');
    expect(find.text('Updated Customer'), findsOneWidget);
    expect(find.text('updated@example.com'), findsOneWidget);
  });

  testWidgets('profile validation waits until save is submitted', (
    tester,
  ) async {
    final auth = FakeCustomerAuthRepository();
    final session = CustomerSession(
      isRestoring: false,
      isAuthenticated: true,
      role: CustomerUserRole.customer,
      hasDeliveryAddress: true,
      user: const CustomerUser(
        id: 1,
        name: 'Customer',
        email: 'customer@example.com',
        role: 'customer',
      ),
    );
    await tester.pumpWidget(
      TalaCustomerApp(
        session: session,
        dependencies: fakeCustomerDependencies(auth: auth),
      ),
    );
    await tester.pump();
    Navigator.of(tester.element(find.byType(CustomerSplash)))
        .pushReplacementNamed(CustomerRoutes.editProfile);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profile-name')), '');
    await tester.pump();
    expect(find.text('Full name is required.'), findsNothing);

    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('Full name is required.'), findsOneWidget);
    expect(auth.updateProfileCalls, 0);
  });
}
