import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
  test('API client sends the app key and bearer token', () async {
    final tokens = MemoryRiderTokenStore();
    await tokens.save('test-token');
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'ok': true},
        }),
        200,
      );
    });
    final api = RiderApiClient(
      client,
      RiderApiConfig(
        baseUrl: 'https://api.example.test/api/v1/',
        apiKey: 'app-key',
      ),
      tokens,
    );

    await api.get('rider/profile');

    expect(
      captured.url.toString(),
      'https://api.example.test/api/v1/rider/profile',
    );
    expect(captured.headers['X-App-Key'], 'app-key');
    expect(captured.headers['Authorization'], 'Bearer test-token');
  });

  test('API client fails clearly when the app key is missing', () async {
    final api = RiderApiClient(
      MockClient((_) async => http.Response('{}', 200)),
      RiderApiConfig(baseUrl: 'https://api.example.test/', apiKey: ''),
      MemoryRiderTokenStore(),
    );

    expect(
      () => api.get('rider/profile'),
      throwsA(
        isA<RiderApiException>().having(
          (error) => error.message,
          'message',
          contains('API key'),
        ),
      ),
    );
  });
}
