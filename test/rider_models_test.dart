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
      'rider_commission': '11.80',
      'pickup_latitude': '14.6000000',
      'pickup_longitude': '120.9800000',
      'delivery_latitude': '14.6100000',
      'delivery_longitude': '120.9900000',
      'created_at': '2026-09-23T01:00:00Z',
      'delivered_at': '2026-09-23T02:00:00Z',
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
    expect(delivery.riderCommission, 11.8);
    expect(delivery.pickupLatitude, 14.6);
    expect(delivery.deliveryLongitude, 120.99);
    expect(delivery.toJson()['pickup_longitude'], 120.98);
    expect(delivery.createdAt, DateTime.utc(2026, 9, 23, 1));
    expect(delivery.deliveredAt, DateTime.utc(2026, 9, 23, 2));
  });

  test('earnings summary parses authoritative server periods', () {
    final summary = RiderEarningsSummary.fromJson({
      'timezone': 'Asia/Manila',
      'earnings_week_type': 'CALENDAR_WEEK',
      'periods': {
        'today': {
          'start': '2026-09-23T00:00:00+08:00',
          'end': '2026-09-23T12:00:00+08:00',
          'completed_deliveries': 2,
          'earnings': '25.50',
        },
        'week': {
          'start': '2026-09-21T00:00:00+08:00',
          'end': '2026-09-23T12:00:00+08:00',
          'completed_deliveries': 5,
          'earnings': 70,
        },
        'month': {
          'start': '2026-09-01T00:00:00+08:00',
          'end': '2026-09-23T12:00:00+08:00',
          'completed_deliveries': 9,
          'earnings': 130,
        },
      },
    });

    expect(summary.today.earnings, 25.5);
    expect(summary.week.completedDeliveries, 5);
    expect(summary.weekType, 'CALENDAR_WEEK');
  });
}
