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

  _paginationChecks();
}

Map<String, dynamic> _deliveryJson(int id) => {
  'id': id,
  'status': 'DELIVERED',
  'pickup_address': 'A Street',
  'delivery_address': 'B Street',
  'distance_km': 1.5,
  'delivery_fee': 60,
  'created_at': '2026-01-01T10:00:00+00:00',
};

Future<RiderRepository> _repositoryFor(MockClient client) async {
  final tokens = MemoryRiderTokenStore();
  await tokens.save('test-token');
  return ApiRiderRepository(
    RiderApiClient(
      client,
      RiderApiConfig(
        baseUrl: 'https://api.example.test/api/v1/',
        apiKey: 'app-key',
      ),
      tokens,
    ),
    tokens,
  );
}

http.Response _paginatedResponse(List<Map<String, dynamic>> items, int page) =>
    http.Response(
      jsonEncode({
        'success': true,
        'message': 'ok',
        'data': {
          'data': items,
          'links': {'first': '?page=1', 'next': page < 2 ? '?page=2' : null},
          'meta': {
            'current_page': page,
            'last_page': 2,
            'per_page': 100,
            'total': 150,
          },
        },
      }),
      200,
    );

void _paginationChecks() {
  test('deliveries follow pagination until the last page', () async {
    final pages = <int>[];
    final repository = await _repositoryFor(
      MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        pages.add(page);
        return _paginatedResponse([_deliveryJson(page)], page);
      }),
    );

    final deliveries = await repository.deliveries();

    expect(pages, [1, 2]);
    expect(deliveries.map((delivery) => delivery.id), [1, 2]);
  });

  test('deliveries accept a plain collection from the server', () async {
    final repository = await _repositoryFor(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': [_deliveryJson(7), _deliveryJson(8)],
          }),
          200,
        ),
      ),
    );

    final deliveries = await repository.deliveries();

    expect(deliveries.map((delivery) => delivery.id), [7, 8]);
  });
}
