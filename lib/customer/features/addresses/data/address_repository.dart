part of '../../../app.dart';

abstract class CustomerAddressRepository {
  Future<List<CustomerAddress>> list();
  Future<CustomerAddress> create(CustomerAddressRequest request);
  Future<CustomerAddress> update(int id, CustomerAddressRequest request);
  Future<void> delete(int id);
}

class ApiCustomerAddressRepository implements CustomerAddressRepository {
  ApiCustomerAddressRepository(this._apiClient);

  final CustomerApiClient _apiClient;

  @override
  Future<List<CustomerAddress>> list() async {
    final payload = await _apiClient.get('addresses');
    final data = payload['data'];
    final items = switch (data) {
      List<dynamic> values => values,
      {'data': List<dynamic> values} => values,
      _ => throw const CustomerApiException(
        'The address list response is invalid.',
      ),
    };
    return items
        .map((item) => CustomerAddress.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<CustomerAddress> create(CustomerAddressRequest request) async {
    final payload = await _apiClient.post('addresses', body: request.toJson());
    final data = payload['data'];
    if (data is Map<String, dynamic>) return CustomerAddress.fromJson(data);
    throw const CustomerApiException('The saved address response is invalid.');
  }

  @override
  Future<CustomerAddress> update(int id, CustomerAddressRequest request) async {
    final payload = await _apiClient.put(
      'addresses/$id',
      body: request.toJson(),
    );
    return CustomerAddress.fromJson(_payloadMap(payload));
  }

  @override
  Future<void> delete(int id) async {
    await _apiClient.delete('addresses/$id');
  }
}
