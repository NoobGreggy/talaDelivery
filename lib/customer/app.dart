import 'dart:async';

import 'package:flutter/material.dart';

part 'shared/theme/theme.dart';
part 'shared/models/catalog_models.dart';
part 'shared/widgets/ui_widgets.dart';
part 'features/auth/auth_screens.dart';
part 'features/home/home_screen.dart';
part 'features/stores/store_screens.dart';
part 'features/products/product_screen.dart';
part 'features/cart/cart_screen.dart';
part 'features/checkout/checkout_screen.dart';
part 'features/orders/order_screens.dart';
part 'features/addresses/address_screens.dart';
part 'features/profile/profile_screen.dart';
part 'core/notifications/notifications_screen.dart';

void main() => runApp(const TalaCustomerApp());

class TalaCustomerApp extends StatelessWidget {
  const TalaCustomerApp({super.key, this.onContinueAsRider});

  final VoidCallback? onContinueAsRider;

  @override
  Widget build(BuildContext context) => RiderSwitchScope(
    onContinueAsRider: onContinueAsRider,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TalaDelivery',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: sky, primary: sky),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            color: text,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
          headlineMedium: TextStyle(
            color: text,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
          titleLarge: TextStyle(color: text, fontWeight: FontWeight.w800),
          titleMedium: TextStyle(color: text, fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(color: text, height: 1.4),
          bodyMedium: TextStyle(color: quiet, height: 1.4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: sky, width: 1.5),
          ),
        ),
      ),
      home: const CustomerSplash(),
    ),
  );
}

class RiderSwitchScope extends InheritedWidget {
  const RiderSwitchScope({
    super.key,
    required super.child,
    required this.onContinueAsRider,
  });

  final VoidCallback? onContinueAsRider;

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RiderSwitchScope>()
      ?.onContinueAsRider;

  @override
  bool updateShouldNotify(RiderSwitchScope oldWidget) =>
      onContinueAsRider != oldWidget.onContinueAsRider;
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    const pages = [HomePage(), OrdersPage(), ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCEEFF),
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
