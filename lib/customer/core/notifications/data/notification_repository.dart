part of '../../../app.dart';

abstract class CustomerNotificationRepository {
  Future<List<CustomerNotification>> list();
  Future<CustomerNotification> markRead(int id);
}

class ApiCustomerNotificationRepository
    implements CustomerNotificationRepository {
  ApiCustomerNotificationRepository(this._apiClient);

  final CustomerApiClient _apiClient;

  @override
  Future<List<CustomerNotification>> list() async {
    final payload = await _apiClient.get('notifications?per_page=100');
    return _payloadList(payload)
        .whereType<Map<String, dynamic>>()
        .map(CustomerNotification.fromJson)
        .toList(growable: false);
  }

  @override
  Future<CustomerNotification> markRead(int id) async =>
      CustomerNotification.fromJson(
        _payloadMap(await _apiClient.post('notifications/$id/read')),
      );
}
