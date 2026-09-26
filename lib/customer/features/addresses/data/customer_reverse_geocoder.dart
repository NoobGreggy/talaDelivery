part of '../../../app.dart';

abstract class CustomerReverseGeocoder {
  Future<CustomerResolvedAddress> reverse(CustomerMapPoint point);
}

class NominatimCustomerReverseGeocoder implements CustomerReverseGeocoder {
  NominatimCustomerReverseGeocoder(this._client, {Uri? endpoint})
    : _endpoint =
          endpoint ??
          Uri.parse(
            const String.fromEnvironment(
              'TALA_GEOCODING_BASE_URL',
              defaultValue: 'https://nominatim.openstreetmap.org/',
            ),
          );

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<CustomerResolvedAddress> reverse(CustomerMapPoint point) async {
    final uri = _endpoint
        .resolve('reverse')
        .replace(
          queryParameters: {
            'format': 'jsonv2',
            'lat': point.latitude.toString(),
            'lon': point.longitude.toString(),
            'addressdetails': '1',
            'zoom': '18',
          },
        );
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'en',
        'User-Agent': 'TalaDeliveryCustomer/1.0',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const CustomerApiException(
        'We could not identify that location. You can enter it manually.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid reverse-geocoding response.');
    }
    final rawAddress = decoded['address'];
    if (rawAddress is! Map<String, dynamic>) {
      throw const FormatException('Missing reverse-geocoding address.');
    }

    String? value(List<String> keys) {
      for (final key in keys) {
        final candidate = rawAddress[key];
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      return null;
    }

    final houseNumber = value(const ['house_number']);
    final road = value(const ['road', 'pedestrian', 'footway', 'path']);
    final street = [houseNumber, road].whereType<String>().join(' ').trim();

    return CustomerResolvedAddress(
      formattedAddress: decoded['display_name'] is String
          ? (decoded['display_name'] as String).trim()
          : [
              street,
              value(const ['city', 'town', 'municipality']),
              value(const ['state']),
            ].whereType<String>().join(', '),
      street: street.isEmpty ? null : street,
      barangay: value(const [
        'barangay',
        'neighbourhood',
        'suburb',
        'quarter',
        'village',
      ]),
      city: value(const ['city', 'town', 'municipality', 'city_district']),
      province: value(const ['state', 'province', 'region']),
      postalCode: value(const ['postcode']),
      country: value(const ['country']),
    );
  }
}
