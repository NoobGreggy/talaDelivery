import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
  test(
    'rejecting an offer refreshes the authoritative acceptance rate',
    () async {
      final repository = _FakeRiderRepository();
      final controller = RiderAppController(repository);
      controller.profile = repository.currentProfile;
      await controller.reject(
        RiderOffer(
          id: 1,
          status: 'PENDING',
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
          delivery: repository.delivery,
        ),
      );
      expect(controller.profile!.acceptanceRate, 50);
      controller.dispose();
    },
  );

  testWidgets('rider signs in and sees live backend state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRiderRepository();
    final dependencies = RiderAppDependencies(
      repository,
      RiderAppController(repository),
    );
    await tester.pumpWidget(
      TalaDeliveryApp(
        dependencies: dependencies,
        themeController: RiderThemeController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rider-login-email')),
      'rider@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('rider-login-password')),
      'password',
    );
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('API Rider'), findsOneWidget);
    expect(find.byKey(const Key('rider-power-button')), findsOneWidget);
    expect(find.text('You’re offline'), findsOneWidget);
    expect(find.text('₱0'), findsOneWidget);

    expect(find.byKey(const Key('rider-wallet-shortcut')), findsOneWidget);
    await tester.ensureVisible(find.text('Acceptance rate'));
    expect(find.text('N/A'), findsOneWidget);
    expect(find.text('On-time rate'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('rider-wallet-shortcut')));
    await tester.tap(find.byKey(const Key('rider-wallet-shortcut')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Available Tala Coins'), findsOneWidget);
    expect(find.byType(RiderCoinImage), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.text('Tala Coins'));
    await tester.tap(find.text('Tala Coins'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Available Tala Coins'), findsOneWidget);
    expect(find.text('No wallet activity yet'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.byKey(const Key('rider-power-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Searching for deliveries…'), findsOneWidget);
    expect(find.text('NEW DELIVERY OFFER'), findsOneWidget);
    expect(find.text('₱13.80'), findsOneWidget);
    expect(find.text('API Mini Mart'), findsOneWidget);
  });
}

class _FakeRiderRepository implements RiderRepository {
  @override
  Future<RiderWallet> wallet() async => const RiderWallet('0.00');
  @override
  Future<RiderWalletPage> walletTransactions({int page = 1}) async =>
      const RiderWalletPage([], 1);

  final user = const RiderUser(
    id: 9,
    name: 'API Rider',
    email: 'rider@example.com',
    role: 'rider',
    phone: '09171234567',
  );
  late RiderProfile currentProfile = RiderProfile(
    id: 4,
    user: user,
    vehicleType: 'MOTORCYCLE',
    vehiclePlate: 'ABC-1234',
    isOnline: false,
    status: 'OFFLINE',
    completedDeliveries: 0,
    totalEarnings: 0,
  );
  late final delivery = RiderDelivery(
    id: 7,
    status: 'UNASSIGNED',
    pickupAddress: '1 Store Street',
    deliveryAddress: '2 Customer Street',
    distanceKm: 7.1,
    deliveryFee: 69,
    riderCommission: 13.8,
    createdAt: DateTime.now(),
    store: const RiderStore(id: 2, name: 'API Mini Mart'),
    order: const RiderOrder(
      number: 'TD-100001',
      total: 399,
      paymentMethod: 'COD',
      customerName: 'API Customer',
    ),
  );

  RiderProfile _profile({required bool online}) => RiderProfile(
    id: currentProfile.id,
    user: user,
    vehicleType: currentProfile.vehicleType,
    vehiclePlate: currentProfile.vehiclePlate,
    isOnline: online,
    status: online ? 'ONLINE' : 'OFFLINE',
    completedDeliveries: currentProfile.completedDeliveries,
    totalEarnings: currentProfile.totalEarnings,
  );

  @override
  Future<RiderUser?> restoreSession() async => null;

  @override
  Future<RiderUser> login({
    required String email,
    required String password,
  }) async => user;

  @override
  Future<void> logout() async {}

  @override
  Future<RiderProfile> profile() async => currentProfile;

  @override
  Future<RiderEarningsSummary> earningsSummary() async {
    final now = DateTime.now();
    final period = RiderEarningsPeriod(
      start: now.subtract(const Duration(days: 7)),
      end: now,
      completedDeliveries: 0,
      earnings: 0,
    );
    return RiderEarningsSummary(
      timezone: 'Asia/Manila',
      weekType: 'ROLLING_SEVEN_DAYS',
      today: period,
      week: period,
      month: period,
    );
  }

  @override
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? heading,
    double? speed,
    DateTime? recordedAt,
  }) async {}

  @override
  Future<List<RiderNotification>> notifications() async => const [];

  @override
  Future<void> markNotificationRead(int notificationId) async {}

  @override
  Future<RiderProfile> setOnline(bool online) async =>
      currentProfile = _profile(online: online);

  @override
  Future<List<RiderOffer>> offers() async => currentProfile.isOnline
      ? [
          RiderOffer(
            id: 3,
            status: 'PENDING',
            expiresAt: DateTime.now().add(const Duration(minutes: 2)),
            delivery: delivery,
          ),
        ]
      : const [];

  @override
  Future<RiderOffer> acceptOffer(int offerId) async => RiderOffer(
    id: offerId,
    status: 'ACCEPTED',
    expiresAt: DateTime.now(),
    delivery: delivery,
  );

  @override
  Future<void> rejectOffer(int offerId) async {
    currentProfile = RiderProfile.fromJson({
      ...currentProfile.toJson(),
      'acceptance_rate': 50,
    });
  }

  @override
  Future<List<RiderDelivery>> deliveries() async => const [];

  @override
  Future<RiderDelivery> updateDelivery(int deliveryId, String action) async =>
      delivery;
}
