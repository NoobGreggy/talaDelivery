part of '../../../app.dart';

abstract class CustomerAuthRepository {
  Future<CustomerUser> login({required String email, required String password});

  Future<CustomerUser> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  });

  Future<CustomerUser?> restoreSession();
  Future<CustomerUser> updateProfile({
    required String name,
    required String email,
    String? phone,
  });
  Future<void> logout();
}

class ApiCustomerAuthRepository implements CustomerAuthRepository {
  ApiCustomerAuthRepository(this._apiClient, this._tokenStore);

  final CustomerApiClient _apiClient;
  final CustomerTokenStore _tokenStore;

  @override
  Future<CustomerUser> login({
    required String email,
    required String password,
  }) async {
    final payload = await _apiClient.post(
      'auth/login',
      authenticated: false,
      body: {'email': email.trim(), 'password': password},
    );
    final result = CustomerAuthResult.fromJson(_data(payload));
    await _tokenStore.save(result.token);
    return result.user;
  }

  @override
  Future<CustomerUser> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final payload = await _apiClient.post(
      'auth/register',
      authenticated: false,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'password': password,
      },
    );
    final result = CustomerAuthResult.fromJson(_data(payload));
    await _tokenStore.save(result.token);
    return result.user;
  }

  @override
  Future<CustomerUser?> restoreSession() async {
    if (await _tokenStore.read() == null) return null;
    try {
      final payload = await _apiClient.get('auth/me');
      return CustomerUser.fromJson(_data(payload));
    } on CustomerApiException catch (error) {
      if (error.statusCode == 401) {
        await _tokenStore.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<CustomerUser> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    final payload = await _apiClient.put(
      'auth/profile',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      },
    );
    return CustomerUser.fromJson(_data(payload));
  }

  @override
  Future<void> logout() async {
    try {
      if (await _tokenStore.read() != null) {
        await _apiClient.post('auth/logout');
      }
    } finally {
      await _tokenStore.clear();
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) return data;
    throw const CustomerApiException('The server response is missing data.');
  }
}
