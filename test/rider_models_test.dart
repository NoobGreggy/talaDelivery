import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
  test('rider profile deserializes API strings and serializes safely', () {
    final profile = RiderProfile.fromJson({
      'id': 4,
      'vehicle_type': 'MOTORCYCLE',
      'vehicle_plate': 'ABC-1234',
      'is_online': true,
      'status': 'ONLINE',
      'completed_deliveries': 12,
      'total_earnings': '840.50',
      'user': {
        'id': 8,
        'name': 'Rider One',
        'email': 'rider@example.com',
        'role': 'rider',
      },
    });

    expect(profile.user.name, 'Rider One');
    expect(profile.totalEarnings, 840.5);
    expect(profile.isOnline, isTrue);
    expect(profile.toJson()['vehicle_type'], 'MOTORCYCLE');
  });

  test('delivery parses its order and store relations', () {
    final delivery = RiderDelivery.fromJson({
      'id': 11,
      'status': 'ASSIGNED',
      'pickup_address': 'Store address',
      'delivery_address': 'Customer address',
      'distance_km': '3.4',
      'delivery_fee': '59.00',
      'store': {'id': 2, 'name': 'Live Store'},
      'order': {
        'id': 15,
        'order_number': 'TD-15',
        'total': '399.00',
        'payment_method': 'COD',
      },
    });

    expect(delivery.isActive, isTrue);
    expect(delivery.store?.name, 'Live Store');
    expect(delivery.order?.total, 399);
  });
}
