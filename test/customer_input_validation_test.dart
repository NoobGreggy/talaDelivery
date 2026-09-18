import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/main.dart';

import 'support/customer_fakes.dart';

void main() {
  testWidgets('login validation waits for the first submit attempt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TalaCustomerApp(dependencies: fakeCustomerDependencies()),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'customer@example.com',
    );
    await tester.pump();
    expect(find.text('Password is required.'), findsNothing);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Password is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-password')),
      'password123',
    );
    await tester.pump();
    expect(find.text('Password is required.'), findsNothing);
  });

  testWidgets('login rejects invalid input before calling the API', (
    WidgetTester tester,
  ) async {
    final auth = FakeCustomerAuthRepository();
    await tester.pumpWidget(
      TalaCustomerApp(dependencies: fakeCustomerDependencies(auth: auth)),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'not-an-email',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'short');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(auth.loginCalls, 0);
  });

  testWidgets('registration validation waits for the first submit attempt', (
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
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register-name')),
      'Maria Santos',
    );
    await tester.pump();
    expect(find.text('Phone number is required.'), findsNothing);
    expect(find.text('Email is required.'), findsNothing);

    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pump();
    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
  });

  testWidgets('login skips address setup when Laravel has a saved address', (
    WidgetTester tester,
  ) async {
    final addresses = FakeCustomerAddressRepository()
      ..addresses = const [
        CustomerAddress(
          id: 1,
          label: 'Home',
          recipientName: 'Test Customer',
          phone: '09171234567',
          addressLine: '123 Example Street',
          city: 'Cabanatuan City',
          province: 'Nueva Ecija',
          isDefault: true,
        ),
      ];
    await tester.pumpWidget(
      TalaCustomerApp(
        dependencies: fakeCustomerDependencies(addresses: addresses),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'customer@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'password123',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Available stores'), findsOneWidget);
    expect(find.text('Where should we deliver?'), findsNothing);
  });

  testWidgets('address setup requires the Laravel address fields', (
    WidgetTester tester,
  ) async {
    final session = CustomerSession(
      isRestoring: false,
      isAuthenticated: true,
      role: CustomerUserRole.customer,
    );
    final addresses = FakeCustomerAddressRepository();
    await tester.pumpWidget(
      TalaCustomerApp(
        session: session,
        dependencies: fakeCustomerDependencies(addresses: addresses),
      ),
    );
    await tester.pump();
    Navigator.of(tester.element(find.byType(CustomerSplash)))
        .pushReplacementNamed(CustomerRoutes.addressSetup);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save delivery address'));
    await tester.pump();

    expect(find.text('Recipient name is required.'), findsOneWidget);
    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(find.text('Street address is required.'), findsOneWidget);
    expect(find.text('City is required.'), findsOneWidget);
    expect(find.text('Province is required.'), findsOneWidget);
    expect(addresses.createCalls, 0);
  });

  testWidgets('registration prefills address contact details', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final addresses = FakeCustomerAddressRepository();
    await tester.pumpWidget(
      TalaCustomerApp(
        dependencies: fakeCustomerDependencies(addresses: addresses),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('register-name')),
      'Maria Santos',
    );
    await tester.enterText(
      find.byKey(const Key('register-phone')),
      '09171234567',
    );
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'maria@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirmation')),
      'password123',
    );
    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    final recipient = tester.widget<TextFormField>(
      find.byKey(const Key('address-recipient')),
    );
    final phone = tester.widget<TextFormField>(
      find.byKey(const Key('address-phone')),
    );
    expect(recipient.controller!.text, 'Maria Santos');
    expect(phone.controller!.text, '09171234567');
    final recipientEditor = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('address-recipient')),
        matching: find.byType(EditableText),
      ),
    );
    final phoneEditor = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('address-phone')),
        matching: find.byType(EditableText),
      ),
    );
    expect(recipientEditor.readOnly, isTrue);
    expect(phoneEditor.readOnly, isTrue);

    await tester.enterText(
      find.byKey(const Key('address-line')),
      '45 Mabini Street',
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

    expect(addresses.createCalls, 1);
    expect(addresses.addresses.single.recipientName, 'Maria Santos');
    expect(addresses.addresses.single.phone, '09171234567');
  });
}
