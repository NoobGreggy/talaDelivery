part of '../app.dart';

abstract class RiderRepository {
  Future<RiderUser?> restoreSession();
  Future<RiderUser> login({required String email, required String password});
  Future<void> logout();
  Future<RiderProfile> profile();
  Future<RiderProfile> setOnline(bool online);
  Future<List<RiderOffer>> offers();
  Future<RiderOffer> acceptOffer(int offerId);
  Future<void> rejectOffer(int offerId);
  Future<List<RiderDelivery>> deliveries();
  Future<RiderEarningsSummary> earningsSummary();
  Future<RiderDelivery> updateDelivery(int deliveryId, String action);
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  });
  Future<List<RiderNotification>> notifications();
  Future<void> markNotificationRead(int notificationId);
}

class ApiRiderRepository implements RiderRepository {
  ApiRiderRepository(this._api, this._tokens);

  final RiderApiClient _api;
  final RiderTokenStore _tokens;

  @override
  Future<RiderUser> login({
    required String email,
    required String password,
  }) async {
    final payload = await _api.post(
      'auth/login',
      authenticated: false,
      body: {'email': email.trim(), 'password': password},
    );
    final result = RiderAuthResult.fromJson(_riderPayloadMap(payload));
    if (result.user.role.toLowerCase() != 'rider') {
      throw const RiderApiException(
        'This account is not registered as a rider.',
        statusCode: 403,
      );
    }
    await _tokens.save(result.token);
    return result.user;
  }

  @override
  Future<RiderUser?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      final user = RiderUser.fromJson(
        _riderPayloadMap(await _api.get('auth/me')),
      );
      if (user.role.toLowerCase() != 'rider') {
        await _tokens.clear();
        return null;
      }
      return user;
    } on RiderApiException catch (error) {
      if (error.statusCode == 401) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (await _tokens.read() != null) await _api.post('auth/logout');
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<RiderProfile> profile() async =>
      RiderProfile.fromJson(_riderPayloadMap(await _api.get('rider/profile')));

  @override
  Future<RiderProfile> setOnline(bool online) async => RiderProfile.fromJson(
    _riderPayloadMap(
      await _api.post(online ? 'rider/online' : 'rider/offline'),
    ),
  );

  @override
  Future<List<RiderOffer>> offers() async =>
      _riderPayloadList(await _api.get('rider/offers'))
          .whereType<Map<String, dynamic>>()
          .map(RiderOffer.fromJson)
          .toList(growable: false);

  @override
  Future<RiderOffer> acceptOffer(int offerId) async => RiderOffer.fromJson(
    _riderPayloadMap(await _api.post('rider/offers/$offerId/accept')),
  );

  @override
  Future<void> rejectOffer(int offerId) async {
    await _api.post('rider/offers/$offerId/reject');
  }

  @override
  Future<List<RiderDelivery>> deliveries() async {
    const perPage = 100;
    var page = 1;
    final all = <RiderDelivery>[];
    while (true) {
      final paged = _riderPayloadPaged(
        await _api.get('rider/deliveries?per_page=$perPage&page=$page'),
      );
      all.addAll(
        paged.items.whereType<Map<String, dynamic>>().map(
          RiderDelivery.fromJson,
        ),
      );
      if (page >= paged.lastPage) break;
      page += 1;
    }
    return List<RiderDelivery>.unmodifiable(all);
  }

  @override
  Future<RiderEarningsSummary> earningsSummary() async =>
      RiderEarningsSummary.fromJson(
        _riderPayloadMap(await _api.get('rider/earnings-summary')),
      );

  @override
  Future<RiderDelivery> updateDelivery(int deliveryId, String action) async =>
      RiderDelivery.fromJson(
        _riderPayloadMap(
          await _api.post('rider/deliveries/$deliveryId/$action'),
        ),
      );

  @override
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _api.post(
      'rider/location',
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  @override
  Future<List<RiderNotification>> notifications() async =>
      _riderPayloadPaged(await _api.get('notifications?per_page=50')).items
          .whereType<Map<String, dynamic>>()
          .map(RiderNotification.fromJson)
          .toList(growable: false);

  @override
  Future<void> markNotificationRead(int notificationId) async {
    await _api.post('notifications/$notificationId/read');
  }
}
