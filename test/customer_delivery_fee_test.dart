import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/main.dart';

import 'support/customer_fakes.dart';

const firstAddress = CustomerAddress(
  id: 1,
  label: 'Home',
  recipientName: 'Customer',
  phone: '09123456789',
  addressLine: 'Street',
  city: 'Makati City',
  province: 'Metro Manila',
  latitude: 14.6,
  longitude: 121.03,
  isDefault: true,
);
const secondAddress = CustomerAddress(
  id: 2,
  label: 'Office',
  recipientName: 'Customer',
  phone: '09123456789',
  addressLine: 'Other Street',
  city: 'Makati City',
  province: 'Metro Manila',
  latitude: 14.7,
  longitude: 121.04,
  isDefault: false,
);

class QuoteOrders extends FakeCustomerOrderRepository {
  final pending = <int, Completer<CustomerDeliveryQuote>>{};
  String? failure;
  final requests = <int>[];
  @override
  Future<CustomerDeliveryQuote> quoteDelivery({
    required StoreData store,
    required CustomerAddress address,
  }) async {
    requests.add(address.id);
    if (failure != null) throw CustomerApiException(failure!);
    return pending[address.id]?.future ??
        const CustomerDeliveryQuote(
          deliveryFee: 49,
          distanceKm: 2,
          zoneName: 'Makati Zone',
        );
  }
}

Future<CustomerAppDependencies> openCheckout(
  WidgetTester tester,
  QuoteOrders orders,
) async {
  final addresses = FakeCustomerAddressRepository()
    ..addresses = [firstAddress, secondAddress];
  final dependencies = fakeCustomerDependencies(
    addresses: addresses,
    orders: orders,
  );
  dependencies.cartController.add(fakeStore, fakeProduct);
  addTearDown(dependencies.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: CustomerDependencyScope(
        dependencies: dependencies,
        child: const CheckoutPage(),
      ),
    ),
  );
  await tester.pump();
  return dependencies;
}

void main() {
  testWidgets(
    'fee is refreshed before confirmation and a changed unavailable zone prevents creation',
    (tester) async {
      final orders = QuoteOrders();
      await openCheckout(tester, orders);
      await tester.pumpAndSettle();
      orders.failure = 'Delivery is not available in the selected city.';
      await tester.tap(find.textContaining('Place order •'));
      await tester.pumpAndSettle();
      expect(orders.requests, [1, 1]);
      expect(orders.orders, isEmpty);
      expect(find.text('Place this order?'), findsNothing);
      expect(
        tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
        isFalse,
      );
    },
  );
  testWidgets('checkout shows the zone fee and total before placement', (
    tester,
  ) async {
    final orders = QuoteOrders();
    final dependencies = await openCheckout(tester, orders);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-delivery-zone')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Delivery zone: Makati Zone'), findsOneWidget);
    expect(
      tester.widget<BottomAction>(find.byType(BottomAction)).label,
      'Place order • ${peso(dependencies.cartController.subtotal + 49)}',
    );
    expect(
      tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
      isTrue,
    );
    expect(orders.orders, isEmpty);
  });
  testWidgets('uncovered address blocks ordering and offers retry', (
    tester,
  ) async {
    final orders = QuoteOrders()
      ..failure = 'Delivery is not available in the selected city.';
    await openCheckout(tester, orders);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delivery is not available in the selected city.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Delivery is not available in the selected city.'),
      findsOneWidget,
    );
    expect(
      tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
      isFalse,
    );
    orders.failure = null;
    await tester.ensureVisible(find.text('Retry delivery fee'));
    await tester.tap(find.text('Retry delivery fee'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
      isTrue,
    );
  });
  testWidgets(
    'changing addresses ignores a stale quote and disables checkout while loading',
    (tester) async {
      final home = Completer<CustomerDeliveryQuote>();
      final office = Completer<CustomerDeliveryQuote>();
      final orders = QuoteOrders()..pending.addAll({1: home, 2: office});
      await openCheckout(tester, orders);
      await tester.pump();
      expect(
        tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
        isFalse,
      );
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged!(2);
      await tester.pump();
      office.complete(
        const CustomerDeliveryQuote(
          deliveryFee: 79,
          distanceKm: 5,
          zoneName: 'Office Zone',
        ),
      );
      await tester.pump();
      await tester.pump();
      home.complete(
        const CustomerDeliveryQuote(
          deliveryFee: 49,
          distanceKm: 2,
          zoneName: 'Home Zone',
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('checkout-delivery-zone')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Office Zone'), findsOneWidget);
      expect(find.textContaining('Home Zone'), findsNothing);
      expect(
        tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
        isTrue,
      );
    },
  );
}
