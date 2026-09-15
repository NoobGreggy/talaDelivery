part of '../../app.dart';

abstract class CustomerTokenStore {
  String? read();
  void save(String token);
  void clear();
}

class MemoryCustomerTokenStore implements CustomerTokenStore {
  String? _token;

  @override
  String? read() => _token;

  @override
  void save(String token) => _token = token;

  @override
  void clear() => _token = null;
}

class CustomerApiException implements Exception {
  const CustomerApiException(
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

class CustomerApiClient {
  CustomerApiClient(this._client, this._config, this._tokenStore);

  final http.Client _client;
  final CustomerApiConfig _config;
  final CustomerTokenStore _tokenStore;

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _send('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body, authenticated: true);

  Future<Map<String, dynamic>> delete(String path) =>
      _send('DELETE', path, authenticated: true);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool authenticated,
  }) async {
    if (_config.apiKey.trim().isEmpty) {
      throw const CustomerApiException(
        'The API key is not configured. Start the app with TALA_API_KEY.',
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-App-Key': _config.apiKey,
    };
    if (authenticated) {
      final token = _tokenStore.read();
      if (token == null || token.isEmpty) {
        throw const CustomerApiException(
          'Your session has expired. Please log in again.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = _config.baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => await _client.put(uri, headers: headers, body: encodedBody),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };

    final payload = _decodePayload(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        payload['success'] != false) {
      return payload;
    }

    throw CustomerApiException(
      payload['message'] is String
          ? payload['message'] as String
          : 'The request could not be completed.',
      statusCode: response.statusCode,
      fieldErrors: _parseFieldErrors(payload['errors']),
    );
  }

  Map<String, dynamic> _decodePayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Converted to a stable API exception below.
    }
    throw const CustomerApiException(
      'The server returned an invalid response.',
    );
  }

  Map<String, String> _parseFieldErrors(Object? errors) {
    if (errors is! Map<String, dynamic>) return const {};
    return errors.map((field, messages) {
      final message = messages is List && messages.isNotEmpty
          ? messages.first.toString()
          : messages.toString();
      return MapEntry(field, message);
    });
  }
}
