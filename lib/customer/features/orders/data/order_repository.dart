part of '../../../app.dart';

abstract class CustomerOrderRepository {
  Future<CustomerDeliveryQuote> quoteDelivery({
    required StoreData store,
    required CustomerAddress address,
  });
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
  Future<CustomerDeliveryQuote> quoteDelivery({
    required StoreData store,
    required CustomerAddress address,
  }) async {
    if (address.latitude == null || address.longitude == null) {
      throw const CustomerApiException(
        'Set a map pin on your delivery address to calculate the delivery fee.',
      );
    }
    final payload = await _apiClient.post(
      'orders/delivery-quote',
      body: {
        'storeId': store.id,
        'deliveryLatitude': address.latitude.toString(),
        'deliveryLongitude': address.longitude.toString(),
        'city': address.city,
        'province': address.province,
      },
    );
    return CustomerDeliveryQuote.fromJson(_payloadMap(payload));
  }

  @override
  Future<List<CustomerOrder>> list() async {
    final items = await _allPages(_apiClient, 'orders');
    return items
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
        'storeId': store.id,
        'items': lines
            .map(
              (line) => {
                'productId': line.product.id,
                'quantity': line.quantity,
              },
            )
            .toList(growable: false),
        'customerName': address.recipientName,
        'customerPhone': address.phone,
        'deliveryAddress': address.formatted,
        'deliveryLatitude': address.latitude?.toString(),
        'deliveryLongitude': address.longitude?.toString(),
        'city': address.city,
        'province': address.province,
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
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
