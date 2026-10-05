import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_rider/main.dart';

String _jwt(int expires) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': expires}))).replaceAll('=', '')}.signature';

void main() {
  test(
    'expired refresh token clears secure session; network failure preserves it',
    () async {
      for (final status in [401, 503]) {
        final tokens = MemoryRiderTokenStore();
        await tokens.save(_jwt(1));
        await tokens.saveRefresh('refresh');
        final api = RiderApiClient(
          MockClient(
            (_) async => http.Response(
              '{"success":false,"message":"Session unavailable."}',
              status,
            ),
          ),
          RiderApiConfig(
            baseUrl: 'http://localhost:3000/api/v1/',
            apiKey: 'app-key',
          ),
          tokens,
        );
        await expectLater(api.accessToken(), throwsA(isA<RiderApiException>()));
        expect(await tokens.readRefresh(), status == 401 ? null : 'refresh');
      }
    },
  );
  test('Nest gateway defaults use the public HTTPS domains', () {
    final config = RiderApiConfig.fromEnvironment();
    expect(config.baseUri.toString(), 'https://api.tala-works.online/api/v1/');
    expect(config.socketUri.toString(), 'https://realtime.tala-works.online');
    expect(
      RiderRealtimeConfig(socketUrl: config.socketUri).namespaceUri.path,
      '/realtime',
    );
  });
  test(
    'Nest order snapshots retain product checklist and customer contact',
    () {
      final order = RiderOrder.fromJson({
        'id': 7,
        'orderNumber': 'ORD-7',
        'paymentMethod': 'COD',
        'customerName': 'Customer',
        'customerPhone': '09123456789',
        'total': '198.00',
        'items': [
          {
            'id': 1,
            'productName': 'Burger',
            'quantity': 2,
            'unitPrice': '99.00',
            'subtotal': '198.00',
          },
        ],
      });
      expect(order.number, 'ORD-7');
      expect(order.customerName, 'Customer');
      expect(order.customerPhone, '09123456789');
      expect(order.items.single.name, 'Burger');
      expect(order.items.single.unitPrice, 99);
    },
  );
  test('Nest notification body is displayed', () {
    expect(
      RiderNotification.fromJson({
        'id': 1,
        'title': 'Delivery',
        'body': 'Your delivery has changed.',
        'is_read': false,
      }).message,
      'Your delivery has changed.',
    );
  });
  test('login saves access and refresh JWTs', () async {
    final tokens = MemoryRiderTokenStore();
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'token': 'access',
            'refresh_token': 'refresh',
            'user': {
              'id': 9,
              'name': 'Rider',
              'email': 'rider@test.com',
              'role': 'rider',
            },
          },
        }),
        200,
      ),
    );
    final repo = ApiRiderRepository(
      RiderApiClient(
        client,
        RiderApiConfig(
          baseUrl: 'http://localhost:3000/api/v1/',
          apiKey: 'app-key',
        ),
        tokens,
      ),
      tokens,
    );
    await repo.login(email: 'rider@test.com', password: 'password');
    expect(await tokens.read(), 'access');
    expect(await tokens.readRefresh(), 'refresh');
  });
  test(
    'concurrent requests share one proactive refresh and rotate both JWTs',
    () async {
      final tokens = MemoryRiderTokenStore();
      await tokens.save(_jwt(1));
      await tokens.saveRefresh('old-refresh');
      var rotations = 0, requests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          rotations++;
          expect(jsonDecode(request.body), {'refresh_token': 'old-refresh'});
          return http.Response(
            jsonEncode({
              'data': {'token': 'new-access', 'refresh_token': 'new-refresh'},
            }),
            200,
          );
        }
        requests++;
        expect(request.headers['Authorization'], 'Bearer new-access');
        return http.Response('{"data":{}}', 200);
      });
      final api = RiderApiClient(
        client,
        RiderApiConfig(
          baseUrl: 'http://localhost:3000/api/v1/',
          apiKey: 'app-key',
        ),
        tokens,
      );
      await Future.wait([
        api.get('rider/profile'),
        api.get('rider/offers'),
        api.accessToken(),
      ]);
      expect(rotations, 1);
      expect(requests, 2);
      expect(await tokens.readRefresh(), 'new-refresh');
    },
  );
  test('401 retries once using a rotated session', () async {
    final tokens = MemoryRiderTokenStore();
    await tokens.save('old-access');
    await tokens.saveRefresh('old-refresh');
    var requests = 0, rotations = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        rotations++;
        return http.Response(
          '{"data":{"token":"new-access","refresh_token":"new-refresh"}}',
          200,
        );
      }
      requests++;
      return request.headers['Authorization'] == 'Bearer new-access'
          ? http.Response('{"data":{}}', 200)
          : http.Response(
              '{"success":false,"message":"Unauthenticated."}',
              401,
            );
    });
    final api = RiderApiClient(
      client,
      RiderApiConfig(
        baseUrl: 'http://localhost:3000/api/v1/',
        apiKey: 'app-key',
      ),
      tokens,
    );
    await api.get('rider/profile');
    expect(requests, 2);
    expect(rotations, 1);
  });
  test('cleared session is not restored by an in-flight rotation', () async {
    final tokens = MemoryRiderTokenStore();
    await tokens.save(_jwt(1));
    await tokens.saveRefresh('old-refresh');
    final response = Completer<http.Response>(), started = Completer<void>();
    final api = RiderApiClient(
      MockClient((_) {
        started.complete();
        return response.future;
      }),
      RiderApiConfig(
        baseUrl: 'http://localhost:3000/api/v1/',
        apiKey: 'app-key',
      ),
      tokens,
    );
    final refreshing = api.accessToken();
    await started.future;
    await tokens.clear();
    response.complete(
      http.Response(
        '{"data":{"token":"access","refresh_token":"refresh"}}',
        200,
      ),
    );
    expect(await refreshing, isNull);
    expect(await tokens.read(), isNull);
    expect(await tokens.readRefresh(), isNull);
  });
}
