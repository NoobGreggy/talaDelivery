import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/customer_app.dart';

import 'support/customer_fakes.dart';

const _grocery = CategoryData(
  id: 7,
  storeId: 3,
  name: 'Groceries',
  status: 'ACTIVE',
);
const _pharmacy = CategoryData(
  id: 8,
  storeId: 4,
  name: 'Pharmacy',
  status: 'ACTIVE',
);

class _DashboardCatalog extends FakeCustomerCatalogRepository {
  _DashboardCatalog({this.includeCategories = true});

  final bool includeCategories;

  @override
  Future<List<StoreData>> listStores({String? search}) async {
    storeSearches.add(search);
    if (!includeCategories) return const [fakeStore];
    return const [
      StoreData(
        id: 3,
        name: 'Grocery Market',
        status: 'ACTIVE',
        categories: [_grocery],
      ),
      StoreData(
        id: 4,
        name: 'Pharmacy Store',
        status: 'ACTIVE',
        categories: [_pharmacy],
      ),
    ];
  }
}

Future<_DashboardCatalog> _openDashboard(
  WidgetTester tester, {
  required Size size,
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  _DashboardCatalog? catalog,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final auth = FakeCustomerAuthRepository()
    ..restoredUser = const CustomerUser(
      id: 1,
      name: 'Test Customer',
      email: 'customer@example.com',
      role: 'customer',
    );
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
  catalog ??= _DashboardCatalog();
  await tester.pumpWidget(
    TalaCustomerApp(
      dependencies: fakeCustomerDependencies(
        auth: auth,
        addresses: addresses,
        catalog: catalog,
      ),
      initialThemeMode: themeMode,
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('home-store-search')), findsOneWidget);
  return catalog;
}

void main() {
  testWidgets('category filters can return to all stores', (tester) async {
    await _openDashboard(tester, size: const Size(390, 844));
    expect(find.text('Grocery Market'), findsOneWidget);
    expect(find.text('Pharmacy Store'), findsOneWidget);

    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();
    expect(find.text('Grocery Market'), findsOneWidget);
    expect(find.text('Pharmacy Store'), findsNothing);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('Grocery Market'), findsOneWidget);
    expect(find.text('Pharmacy Store'), findsOneWidget);
  });

  testWidgets('dashboard header stays below the phone status area', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await _openDashboard(tester, size: const Size(393, 852));

    expect(tester.getTopLeft(find.text('DELIVER TO')).dy, greaterThan(59));
    expect(tester.takeException(), isNull);
  });

  testWidgets('category section remains visible without category data', (
    tester,
  ) async {
    await _openDashboard(
      tester,
      size: const Size(390, 844),
      catalog: _DashboardCatalog(includeCategories: false),
    );

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(
      find.text('Store categories will appear here when available.'),
      findsOneWidget,
    );
  });

  testWidgets('dark dashboard and profile fit a narrow phone', (tester) async {
    await _openDashboard(
      tester,
      size: const Size(320, 640),
      themeMode: ThemeMode.dark,
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull, reason: 'dashboard layout');
    expect(
      tester.widget<Text>(find.text('What you need,')).style?.color,
      AppPalette.dark.text,
    );
    final selectedCategory = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(TalaCategoryChip).first,
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (selectedCategory.decoration! as BoxDecoration).color,
      isNot(AppPalette.dark.brand),
      reason: 'white category text needs a contrasting dark-mode fill',
    );
    await tester.scrollUntilVisible(
      find.text('Grocery Market'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'market card layout');
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'profile layout');
    await tester.scrollUntilVisible(
      find.text('System'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'appearance settings layout',
    );
  });

  testWidgets('dashboard search opens store results with the entered query', (
    tester,
  ) async {
    final catalog = await _openDashboard(tester, size: const Size(390, 844));
    await tester.enterText(
      find.byKey(const Key('home-store-search')),
      'Grocery',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-search')), findsOneWidget);
    expect(catalog.storeSearches.last, 'Grocery');
  });

  testWidgets('dashboard search icon and store card open their destinations', (
    tester,
  ) async {
    final catalog = await _openDashboard(tester, size: const Size(390, 844));
    await tester.enterText(
      find.byKey(const Key('home-store-search')),
      'Pharmacy',
    );
    await tester.tap(find.byTooltip('Search stores'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-search')), findsOneWidget);
    expect(catalog.storeSearches.last, 'Pharmacy');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grocery Market'));
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsOneWidget);
  });

  testWidgets('order confirmation fits a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppPalette.dark),
        home: OrderSuccessPage(
          order: CustomerOrder(
            id: 1,
            orderNumber: 'TLD-TEST-001',
            status: 'PENDING',
            statusLabel: 'Pending',
            paymentMethod: 'Cash on Delivery',
            subtotal: 125,
            deliveryFee: 49,
            discount: 0,
            total: 174,
            deliveryAddress: 'Cabanatuan City',
            createdAt: DateTime(2026, 9, 19),
            store: fakeStore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Track order'), findsOneWidget);
  });
}
