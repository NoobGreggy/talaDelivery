import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/main.dart';

import 'support/customer_fakes.dart';
import 'customer_delivery_fee_test.dart'
    show QuoteOrders, firstAddress, secondAddress;

Future<CustomerAppDependencies> openCart(
  WidgetTester tester,
  QuoteOrders orders, {
  bool hasAddresses = true,
}) async {
  final addresses = FakeCustomerAddressRepository()
    ..addresses = hasAddresses ? [firstAddress, secondAddress] : [];
  final dependencies = fakeCustomerDependencies(
    addresses: addresses,
    orders: orders,
  );
  dependencies.cartController.add(fakeStore, fakeProduct);
  addTearDown(dependencies.dispose);
  await tester.pumpWidget(
    CustomerDependencyScope(
      dependencies: dependencies,
      child: MaterialApp(
        home: const CartPage(),
        onGenerateRoute: (settings) {
          if (settings.name == CustomerRoutes.checkout) {
            final args = settings.arguments! as CustomerCheckoutRouteArgs;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => CheckoutPage(initialAddressId: args.addressId),
            );
          }
          return null;
        },
      ),
    ),
  );
  await tester.pump();
  return dependencies;
}

void main() {
  testWidgets(
    'cart calculates delivery before proceeding and updates total when quantity changes',
    (tester) async {
      final orders = QuoteOrders();
      final dependencies = await openCart(tester, orders);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(PriceSummary),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Calculated by API'), findsNothing);
      expect(
        tester.widget<PriceSummary>(find.byType(PriceSummary)).delivery,
        49,
      );
      expect(
        tester.widget<BottomAction>(find.byType(BottomAction)).label,
        'Continue to checkout • ${peso(dependencies.cartController.subtotal + 49)}',
      );
      dependencies.cartController.setQuantity(fakeProduct.id, 2);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PriceSummary>(find.byType(PriceSummary)).total,
        dependencies.cartController.subtotal + 49,
      );
      expect(orders.requests, [1]);
    },
  );
  testWidgets('cart preserves the chosen delivery address in checkout', (
    tester,
  ) async {
    final orders = QuoteOrders();
    await openCart(tester, orders);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('cart-delivery-address')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const Key('cart-delivery-address')),
        )
        .onChanged!(2);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Continue to checkout •'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(
      tester.widget<CheckoutPage>(find.byType(CheckoutPage)).initialAddressId,
      2,
    );
    expect(orders.requests.last, 2);
  });
  testWidgets(
    'cart blocks checkout while calculating and ignores stale address fees',
    (tester) async {
      final home = Completer<CustomerDeliveryQuote>();
      final office = Completer<CustomerDeliveryQuote>();
      final orders = QuoteOrders()..pending.addAll({1: home, 2: office});
      final dependencies = await openCart(tester, orders);
      await tester.pump();
      expect(
        tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
        isFalse,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('cart-delivery-address')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('cart-delivery-address')),
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
      expect(
        tester.widget<BottomAction>(find.byType(BottomAction)).label,
        'Continue to checkout • ${peso(dependencies.cartController.subtotal + 79)}',
      );
      expect(
        tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
        isTrue,
      );
    },
  );
  testWidgets('cart shows coverage error, blocks proceeding and can retry', (
    tester,
  ) async {
    final orders = QuoteOrders()
      ..failure = 'Delivery is not available in the selected city.';
    await openCart(tester, orders);
    await tester.pumpAndSettle();
    expect(
      tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.text('Retry delivery fee'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Delivery is not available in the selected city.'),
      findsOneWidget,
    );
    orders.failure = null;
    await tester.tap(find.text('Retry delivery fee'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BottomAction>(find.byType(BottomAction)).enabled,
      isTrue,
    );
    expect(orders.orders, isEmpty);
  });
  testWidgets('cart requires an address before estimating delivery', (
    tester,
  ) async {
    final orders = QuoteOrders();
    await openCart(tester, orders, hasAddresses: false);
    await tester.pumpAndSettle();
    expect(find.text('Delivery address required'), findsOneWidget);
    expect(find.byType(BottomAction), findsNothing);
    expect(orders.requests, isEmpty);
  });
}
