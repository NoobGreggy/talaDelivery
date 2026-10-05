part of '../../app.dart';

/// Directions use the saved delivery pin, never a customer's live GPS.
class RiderNavigation {
  static bool valid(RiderLatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude.abs() <= 90 &&
      point.longitude.abs() <= 180;

  static Uri googleMaps(RiderLatLng destination) {
    if (!valid(destination)) throw ArgumentError('Invalid destination');
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
  }

  static Uri appleMaps(RiderLatLng destination) {
    if (!valid(destination)) throw ArgumentError('Invalid destination');
    return Uri.https('maps.apple.com', '/', {
      'daddr': '${destination.latitude},${destination.longitude}',
      'dirflg': 'd',
    });
  }

  static RiderLatLng? destination(RiderDelivery delivery, DeliveryStage stage) {
    final pickup =
        stage == DeliveryStage.toStore || stage == DeliveryStage.atStore;
    final latitude = pickup
        ? delivery.pickupLatitude
        : delivery.deliveryLatitude;
    final longitude = pickup
        ? delivery.pickupLongitude
        : delivery.deliveryLongitude;
    if (latitude == null || longitude == null) return null;
    final point = RiderLatLng(latitude, longitude);
    return valid(point) ? point : null;
  }
}

/// Real road geometry. Failure means no route, never a misleading straight line.
class RiderRoadRoutes {
  RiderRoadRoutes({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<mapbox.Position>> driving(
    RiderLatLng from,
    RiderLatLng to,
    String accessToken,
  ) async {
    if (!RiderNavigation.valid(from) || !RiderNavigation.valid(to)) {
      return const [];
    }
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'false',
        'access_token': accessToken,
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return const [];
    return parseGeometry(jsonDecode(response.body));
  }

  static List<mapbox.Position> parseGeometry(dynamic data) {
    if (data is! Map || data['code'] != 'Ok') return const [];
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      return const [];
    }
    final geometry = routes.first['geometry'];
    if (geometry is! Map || geometry['type'] != 'LineString') return const [];
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return const [];
    final result = <mapbox.Position>[];
    for (final pair in coordinates) {
      if (pair is! List ||
          pair.length < 2 ||
          pair[0] is! num ||
          pair[1] is! num) {
        return const [];
      }
      final point = RiderLatLng(
        (pair[1] as num).toDouble(),
        (pair[0] as num).toDouble(),
      );
      if (!RiderNavigation.valid(point)) return const [];
      result.add(mapbox.Position(point.longitude, point.latitude));
    }
    return result;
  }

  void dispose() => _client.close();
}
