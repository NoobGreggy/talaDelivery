part of '../../../app.dart';

abstract class CustomerOrderRepository {
  Future<List<CustomerOrder>> list();
  Future<CustomerOrder> get(int id);
  Future<CustomerOrder> create({
    required StoreData store,
    required List<CustomerCartLine> lines,
    required CustomerAddress address,
    String? notes,
  });
  Future<CustomerOrder> cancel(int id, {String? reason});
}

class ApiCustomerOrderRepository implements CustomerOrderRepository {
  ApiCustomerOrderRepository(this._apiClient);

  final CustomerApiClient _apiClient;

  @override
  Future<List<CustomerOrder>> list() async {
    final payload = await _apiClient.get('orders?per_page=100');
    return _payloadList(payload)
        .whereType<Map<String, dynamic>>()
        .map(CustomerOrder.fromJson)
        .toList(growable: false);
  }

  @override
  Future<CustomerOrder> get(int id) async =>
      CustomerOrder.fromJson(_payloadMap(await _apiClient.get('orders/$id')));

  @override
  Future<CustomerOrder> create({
    required StoreData store,
    required List<CustomerCartLine> lines,
    required CustomerAddress address,
    String? notes,
  }) async {
    final payload = await _apiClient.post(
      'orders',
      body: {
        'store_id': store.id,
        'items': lines
            .map(
              (line) => {
                'product_id': line.product.id,
                'quantity': line.quantity,
              },
            )
            .toList(growable: false),
        'customer_name': address.recipientName,
        'customer_phone': address.phone,
        'delivery_address': address.formatted,
        'delivery_latitude': address.latitude,
        'delivery_longitude': address.longitude,
        'city': address.city,
        'province': address.province,
        'payment_method': 'COD',
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      },
    );
    return CustomerOrder.fromJson(_payloadMap(payload));
  }

  @override
  Future<CustomerOrder> cancel(int id, {String? reason}) async {
    final payload = await _apiClient.post(
      'orders/$id/cancel',
      body: {'reason': reason?.trim().isEmpty == true ? null : reason?.trim()},
    );
    return CustomerOrder.fromJson(_payloadMap(payload));
  }
}
