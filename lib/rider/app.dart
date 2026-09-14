import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

part 'shared/theme/theme.dart';
part 'shared/models/delivery_stage.dart';
part 'shared/widgets/ui_widgets.dart';
part 'features/auth/auth_screens.dart';
part 'features/dashboard/dashboard_screen.dart';
part 'features/offers/offer_screen.dart';
part 'features/deliveries/delivery_screens.dart';
part 'features/history/history_screen.dart';
part 'features/profile/profile_screen.dart';

void main() => runApp(const TalaDeliveryApp());

class TalaDeliveryApp extends StatelessWidget {
  const TalaDeliveryApp({super.key, this.onContinueAsCustomer});

  final VoidCallback? onContinueAsCustomer;

  @override
  Widget build(BuildContext context) => CustomerSwitchScope(
    onContinueAsCustomer: onContinueAsCustomer,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TalaDelivery Rider',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue),
        scaffoldBackgroundColor: canvas,
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontWeight: FontWeight.w800,
            color: ink,
            height: 1.05,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w800,
            color: ink,
            height: 1.12,
          ),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
          bodyLarge: TextStyle(color: ink, height: 1.4),
          bodyMedium: TextStyle(color: muted, height: 1.4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFDDE7F1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFDDE7F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 1.5),
          ),
        ),
      ),
      home: const SplashScreen(),
    ),
  );
}

class CustomerSwitchScope extends InheritedWidget {
  const CustomerSwitchScope({
    super.key,
    required super.child,
    required this.onContinueAsCustomer,
  });

  final VoidCallback? onContinueAsCustomer;

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CustomerSwitchScope>()
      ?.onContinueAsCustomer;

  @override
  bool updateShouldNotify(CustomerSwitchScope oldWidget) =>
      onContinueAsCustomer != oldWidget.onContinueAsCustomer;
}

class RiderShell extends StatefulWidget {
  const RiderShell({super.key});
  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  int tab = 0;
  bool online = false;
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        online: online,
        onToggle: () => setState(() => online = !online),
        onOffer: () =>
            Navigator.of(context).push(slideRoute(const OfferScreen())),
        onEarnings: () => setState(() => tab = 1),
      ),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCEEFF),
        height: 72,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
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
