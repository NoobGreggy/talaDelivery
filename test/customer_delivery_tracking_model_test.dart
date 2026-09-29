import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/main.dart';

void main() {
  testWidgets(
    'customer map waits for the rider instead of showing endpoint pins',
    (tester) async {
      const delivery = CustomerDelivery(
        id: 22,
        status: 'ASSIGNED',
        pickupLatitude: 14.6,
        pickupLongitude: 120.98,
        deliveryLatitude: 14.61,
        deliveryLongitude: 120.99,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppPalette.light),
          home: const Scaffold(body: CustomerDeliveryMap(delivery: delivery)),
        ),
      );

      expect(
        find.text(
          'The rider’s live location will appear here once it is available.',
        ),
        findsOneWidget,
      );
    },
  );

  test('customer order parses delivery pins and latest rider location', () {
    final order = CustomerOrder.fromJson({
      'id': 1,
      'order_number': 'TLD-1',
      'status': 'RIDER_ASSIGNED',
      'delivery_address': 'Customer address',
      'delivery': {
        'id': 22,
        'status': 'ASSIGNED',
        'pickup_latitude': '14.6000000',
        'pickup_longitude': '120.9800000',
        'delivery_latitude': '14.6100000',
        'delivery_longitude': '120.9900000',
        'rider_location': {
          'latitude': '14.6050000',
          'longitude': '120.9850000',
          'recorded_at': '2026-09-24T10:20:30Z',
        },
      },
    });

    expect(order.delivery?.isTrackable, isTrue);
    expect(order.delivery?.pickupPoint?.latitude, 14.6);
    expect(order.delivery?.deliveryPoint?.longitude, 120.99);
    expect(order.delivery?.riderLocation?.deliveryId, 22);
    expect(order.delivery?.riderLocation?.hasCoordinates, isTrue);
  });

  test('rider location serialization preserves ordering fields', () {
    final location = CustomerRiderLocation.fromJson({
      'delivery_id': 22,
      'rider_id': 7,
      'latitude': 14.6,
      'longitude': 120.98,
      'sequence': 44,
      'recorded_at': '2026-09-24T10:20:30Z',
    });

    expect(location.toJson()['sequence'], 44);
    expect(location.toJson()['delivery_id'], 22);
  });
}
