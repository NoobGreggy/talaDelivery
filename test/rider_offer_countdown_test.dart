import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
  testWidgets('incoming offer expires after exactly twelve seconds', (
    tester,
  ) async {
    var expired = false;
    final offer = RiderOffer(
      id: 4,
      status: 'PENDING',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      delivery: RiderDelivery(
        id: 8,
        status: 'UNASSIGNED',
        pickupAddress: 'Store address',
        deliveryAddress: 'Customer address',
        distanceKm: 2.4,
        deliveryFee: 55,
        riderCommission: 22,
        createdAt: DateTime(2026, 9, 29),
        store: const RiderStore(id: 2, name: 'Test Store'),
        order: const RiderOrder(
          number: 'TD-8',
          total: 250,
          paymentMethod: 'COD',
          customerName: 'Test Customer',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRiderTheme(RiderPalette.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RiderIncomingOfferSheet(
              offer: offer,
              busy: false,
              onAccept: () {},
              onReject: () {},
              onExpired: () => expired = true,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 11));
    expect(expired, isFalse);
    await tester.pump(const Duration(seconds: 1, milliseconds: 1));
    expect(expired, isTrue);
  });
}
