import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
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
    await tester.pumpAndSettle();

    expect(find.text('API Rider'), findsOneWidget);
    expect(find.text('Go online'), findsOneWidget);
    expect(find.text('₱0'), findsOneWidget);

    await tester.tap(find.text('Go online'));
    await tester.pumpAndSettle();
    expect(find.text('1 delivery offer'), findsOneWidget);

    await tester.tap(find.text('1 delivery offer'));
    await tester.pumpAndSettle();
    expect(find.text('₱69 estimated earnings'), findsOneWidget);
    expect(find.text('API Mini Mart'), findsOneWidget);
  });
}

class _FakeRiderRepository implements RiderRepository {
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
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
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
  Future<void> rejectOffer(int offerId) async {}

  @override
  Future<List<RiderDelivery>> deliveries() async => const [];

  @override
  Future<RiderDelivery> updateDelivery(int deliveryId, String action) async =>
      delivery;
}
