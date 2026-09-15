part of '../../app.dart';

abstract class RiderTokenStore {
  Future<String?> read();
  Future<void> save(String token);
  Future<void> clear();
}

class PreferencesRiderTokenStore implements RiderTokenStore {
  PreferencesRiderTokenStore(this._preferences);

  static const _key = 'rider_auth_token';
  final SharedPreferences _preferences;

  @override
  Future<String?> read() async => _preferences.getString(_key);

  @override
  Future<void> save(String token) => _preferences.setString(_key, token);

  @override
  Future<void> clear() => _preferences.remove(_key);
}

class MemoryRiderTokenStore implements RiderTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
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
      final token = await _tokenStore.read();
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
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };
    final payload = _decode(response.body);
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
