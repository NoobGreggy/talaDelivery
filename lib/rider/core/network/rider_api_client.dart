part of '../../app.dart';

abstract class RiderTokenStore {
  Future<String?> read();
  Future<void> save(String token);
  Future<String?> readRefresh();
  Future<void> saveRefresh(String token);
  Future<void> clear();
}

class PreferencesRiderTokenStore implements RiderTokenStore {
  PreferencesRiderTokenStore(this._preferences);

  static const _key = 'rider_auth_token';
  static const _refreshKey = 'rider_refresh_token';
  final SharedPreferences _preferences;

  @override
  Future<String?> read() async => _preferences.getString(_key);

  @override
  Future<void> save(String token) => _preferences.setString(_key, token);

  @override
  Future<String?> readRefresh() async => _preferences.getString(_refreshKey);

  @override
  Future<void> saveRefresh(String token) async =>
      _preferences.setString(_refreshKey, token);

  @override
  Future<void> clear() async {
    await _preferences.remove(_key);
    await _preferences.remove(_refreshKey);
  }
}

class SecureRiderTokenStore implements RiderTokenStore {
  SecureRiderTokenStore(this._storage);

  static const _key = 'rider_auth_token';
  static const _refreshKey = 'rider_refresh_token';
  final FlutterSecureStorage _storage;

  /// Creates a store for platform secure storage, migrating any token that a
  /// previous version left in SharedPreferences.
  static Future<SecureRiderTokenStore> createAndMigrate({
    required SharedPreferences legacy,
  }) async {
    final store = SecureRiderTokenStore(const FlutterSecureStorage());
    await store._migrateFromLegacy(legacy);
    return store;
  }

  Future<void> _migrateFromLegacy(SharedPreferences legacy) async {
    if (await _storage.read(key: _key) != null) return;
    final old = legacy.getString(_key);
    if (old != null && old.isNotEmpty) {
      await _storage.write(key: _key, value: old);
      await legacy.remove(_key);
    }
  }

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> save(String token) => _storage.write(key: _key, value: token);

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  @override
  Future<void> saveRefresh(String token) =>
      _storage.write(key: _refreshKey, value: token);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _refreshKey);
  }
}

class MemoryRiderTokenStore implements RiderTokenStore {
  String? token;
  String? refreshToken;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<String?> readRefresh() async => refreshToken;

  @override
  Future<void> saveRefresh(String token) async => refreshToken = token;

  @override
  Future<void> clear() async {
    token = null;
    refreshToken = null;
  }
}

class RiderApiException implements Exception {
  const RiderApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

class RiderApiClient {
  RiderApiClient(this._client, this._config, this._tokenStore);

  final http.Client _client;
  final RiderApiConfig _config;
  final RiderTokenStore _tokenStore;
  Future<String?>? _refreshing;

  /// Refresh expiring access JWTs before HTTP requests and socket reconnects.
  /// The expiry is only a scheduling hint; the backend validates the JWT.
  Future<String?> accessToken() async {
    final token = await _tokenStore.read();
    if (token == null) return null;
    num? expiry;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (claims is Map && claims['exp'] is num) {
          expiry = claims['exp'] as num;
        }
      }
    } catch (_) {
      /* The server handles malformed tokens. */
    }
    if (expiry != null &&
        expiry * 1000 <= DateTime.now().millisecondsSinceEpoch + 30000) {
      return _refreshAccess();
    }
    return token;
  }

  Future<String?> _refreshAccess() async {
    if (_refreshing != null) return _refreshing;
    final future = _rotate();
    _refreshing = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshing, future)) _refreshing = null;
    }
  }

  Future<String?> _rotate() async {
    final refresh = await _tokenStore.readRefresh();
    if (refresh == null) return null;
    late Map<String, dynamic> payload;
    try {
      payload = await _send(
        'POST',
        'auth/refresh',
        body: {'refresh_token': refresh},
        authenticated: false,
      );
    } on RiderApiException catch (error) {
      if ((error.statusCode == 401 || error.statusCode == 403) &&
          await _tokenStore.readRefresh() == refresh) {
        await _tokenStore.clear();
      }
      rethrow;
    }
    final data = _riderPayloadMap(payload);
    final token = data['token'], nextRefresh = data['refresh_token'];
    if (token is! String || nextRefresh is! String) {
      throw const RiderApiException('Invalid session refresh response.');
    }
    // Logout/new login while rotation was in flight must not restore an old session.
    if (await _tokenStore.readRefresh() != refresh) return null;
    await _tokenStore.saveRefresh(nextRefresh);
    await _tokenStore.save(token);
    return token;
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _send('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool authenticated,
    bool retry = true,
  }) async {
    if (_config.apiKey.trim().isEmpty) {
      throw const RiderApiException(
        'The API key is not configured. Launch with TALA_API_KEY.',
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-App-Key': _config.apiKey,
    };
    if (authenticated) {
      final token = await accessToken();
      if (token == null || token.isEmpty) {
        throw const RiderApiException(
          'Your session has expired. Please log in again.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = _config.baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    final startedAt = DateTime.now();
    try {
      final response = switch (method) {
        'GET' =>
          await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20)),
        'POST' =>
          await _client
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20)),
        _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
      };
      final payload = _decode(response.body);
      if (response.statusCode == 401 && authenticated && retry) {
        final current = await _tokenStore.read();
        if (current != headers['Authorization']?.substring(7) ||
            await _refreshAccess() != null) {
          return await _send(
            method,
            path,
            body: body,
            authenticated: true,
            retry: false,
          );
        }
      }
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          payload['success'] != false) {
        return payload;
      }
      throw RiderApiException(
        payload['message'] is String
            ? payload['message'] as String
            : 'The request could not be completed.',
        statusCode: response.statusCode,
        fieldErrors: _fieldErrors(payload['errors']),
      );
    } finally {
      _riderPerfTrace('rider.api $method $path', startedAt);
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Replaced with the stable message below.
    }
    throw const RiderApiException('The server returned an invalid response.');
  }

  Map<String, String> _fieldErrors(Object? errors) {
    if (errors is! Map<String, dynamic>) return const {};
    return errors.map((field, messages) {
      final value = messages is List && messages.isNotEmpty
          ? messages.first
          : messages;
      return MapEntry(field, value.toString());
    });
  }
}
