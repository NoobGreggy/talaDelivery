import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/main.dart';

import 'support/customer_fakes.dart';

void main() {
  testWidgets('home search accepts text and searches Laravel stores', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = FakeCustomerCatalogRepository();
    final addresses = FakeCustomerAddressRepository()
      ..addresses = const [
        CustomerAddress(
          id: 1,
          recipientName: 'Test Customer',
          phone: '09171234567',
          addressLine: '123 Example Street',
          city: 'Cabanatuan City',
          province: 'Nueva Ecija',
          isDefault: true,
        ),
      ];
    final session = CustomerSession(
      isRestoring: false,
      isAuthenticated: true,
      role: CustomerUserRole.customer,
      hasDeliveryAddress: true,
      user: const CustomerUser(
        id: 1,
        name: 'Test Customer',
        email: 'customer@example.com',
        role: 'customer',
      ),
    );
    await tester.pumpWidget(
      TalaCustomerApp(
        session: session,
        dependencies: fakeCustomerDependencies(
          addresses: addresses,
          catalog: catalog,
        ),
      ),
    );
    await tester.pump();
    Navigator.of(tester.element(find.byType(CustomerSplash)))
        .pushReplacementNamed(CustomerRoutes.home);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('home-store-search')),
      'API Store',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byType(StoreListingPage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('store-search')))
          .controller
          ?.text,
      'API Store',
    );
    expect(catalog.storeSearches.last, 'API Store');
    expect(
      find.descendant(
        of: find.byType(StoreCard),
        matching: find.text('API Store'),
      ),
      findsOneWidget,
    );
  });
}
