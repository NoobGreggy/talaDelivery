import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
  final delivery = RiderDelivery.fromJson({
    'id': 22,
    'status': 'ASSIGNED',
    'pickup_latitude': 16.94,
    'pickup_longitude': 121.76,
    'delivery_latitude': 16.95,
    'delivery_longitude': 121.77,
  });
  test('pickup stages route to store; after pickup route to delivery pin', () {
    for (final stage in [DeliveryStage.toStore, DeliveryStage.atStore]) {
      expect(RiderNavigation.destination(delivery, stage)?.latitude, 16.94);
    }
    for (final stage in [DeliveryStage.toCustomer, DeliveryStage.atCustomer]) {
      expect(RiderNavigation.destination(delivery, stage)?.latitude, 16.95);
    }
  });
  test('Google and Apple Maps start driving from the device location', () {
    const target = RiderLatLng(16.95, 121.77);
    final google = RiderNavigation.googleMaps(target);
    expect(google.queryParameters, containsPair('destination', '16.95,121.77'));
    expect(google.queryParameters['api'], '1');
    expect(google.queryParameters['dir_action'], 'navigate');
    expect(google.queryParameters.containsKey('origin'), false);
    final apple = RiderNavigation.appleMaps(target);
    expect(apple.host, 'maps.apple.com');
    expect(apple.queryParameters['daddr'], '16.95,121.77');
    expect(apple.queryParameters['dirflg'], 'd');
    expect(apple.queryParameters.containsKey('saddr'), false);
    expect(
      () => RiderNavigation.googleMaps(const RiderLatLng(91, 121)),
      throwsArgumentError,
    );
  });
  test(
    'directions request returns real road geometry, not endpoints',
    () async {
      final routes = RiderRoadRoutes(
        client: MockClient((request) async {
          expect(request.url.host, 'api.mapbox.com');
          expect(
            request.url.path,
            contains('/mapbox/driving/121.76,16.94;121.77,16.95'),
          );
          expect(request.url.queryParameters['geometries'], 'geojson');
          return http.Response(
            '{"code":"Ok","routes":[{"geometry":{"type":"LineString","coordinates":[[121.76,16.94],[121.765,16.942],[121.77,16.95]]}}]}',
            200,
          );
        }),
      );
      expect(
        await routes.driving(
          const RiderLatLng(16.94, 121.76),
          const RiderLatLng(16.95, 121.77),
          'test-public-token',
        ),
        hasLength(3),
      );
      routes.dispose();
    },
  );
  test('missing and malformed road routes do not invent a route', () {
    expect(
      RiderRoadRoutes.parseGeometry({'code': 'NoRoute', 'routes': []}),
      isEmpty,
    );
    expect(
      RiderRoadRoutes.parseGeometry({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [121, 91],
                [121, 14],
              ],
            },
          },
        ],
      }),
      isEmpty,
    );
  });
}
