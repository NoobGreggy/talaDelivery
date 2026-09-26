import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_customer/main.dart';

import 'support/customer_fakes.dart';

class _FakeLocationService implements CustomerLocationService {
  _FakeLocationService(this.result);

  final CustomerLocationResult result;
  int calls = 0;

  @override
  Future<CustomerLocationResult> currentLocation() async {
    calls++;
    return result;
  }
}

class _FakeReverseGeocoder implements CustomerReverseGeocoder {
  int calls = 0;

  @override
  Future<CustomerResolvedAddress> reverse(CustomerMapPoint point) async {
    calls++;
    return const CustomerResolvedAddress(
      formattedAddress: '42 Mabini Street, Barangay Centro, Cabanatuan City',
      street: '42 Mabini Street',
      barangay: 'Barangay Centro',
      city: 'Cabanatuan City',
      province: 'Nueva Ecija',
      postalCode: '3100',
      country: 'Philippines',
    );
  }
}

void main() {
  testWidgets(
    'current location moves the pin and fills editable address fields',
    (tester) async {
      final location = _FakeLocationService(
        const CustomerLocationResult(
          CustomerLocationStatus.available,
          point: CustomerMapPoint(15.4865, 120.9734),
        ),
      );
      final geocoder = _FakeReverseGeocoder();
      final session = CustomerSession(
        isRestoring: false,
        isAuthenticated: true,
        role: CustomerUserRole.customer,
        user: const CustomerUser(
          id: 4,
          name: 'Maria Santos',
          email: 'maria@example.test',
          phone: '09171234567',
          role: 'customer',
        ),
      );
      await tester.pumpWidget(
        TalaCustomerApp(
          session: session,
          dependencies: fakeCustomerDependencies(
            locationService: location,
            reverseGeocoder: geocoder,
          ),
        ),
      );
      await tester.pump();
      Navigator.of(tester.element(find.byType(CustomerSplash)))
          .pushReplacementNamed(CustomerRoutes.addressSetup);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('address-use-current-location')));
      await tester.pumpAndSettle();

      expect(location.calls, 1);
      expect(geocoder.calls, 1);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('address-line')))
            .controller!
            .text,
        '42 Mabini Street',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('address-city')))
            .controller!
            .text,
        'Cabanatuan City',
      );
      expect(
        find.textContaining('42 Mabini Street, Barangay Centro'),
        findsOneWidget,
      );
    },
  );

  testWidgets('denied permission keeps manual address entry available', (
    tester,
  ) async {
    final location = _FakeLocationService(
      const CustomerLocationResult(CustomerLocationStatus.permissionDenied),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerAddressMapPicker(
            locationService: location,
            surfaceBuilder: (center, selectedPoint, onSelect) =>
                const SizedBox.expand(),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('address-use-current-location')));
    await tester.pump();

    expect(find.textContaining('permission was not granted'), findsOneWidget);
    expect(find.byKey(const Key('address-enter-manually')), findsOneWidget);
  });

  test('Nominatim response maps to customer address fields', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/reverse');
      expect(request.url.queryParameters['format'], 'jsonv2');
      return http.Response(
        jsonEncode({
          'display_name': '42 Mabini Street, Centro, Cabanatuan City',
          'address': {
            'house_number': '42',
            'road': 'Mabini Street',
            'barangay': 'Centro',
            'city': 'Cabanatuan City',
            'state': 'Nueva Ecija',
            'postcode': '3100',
            'country': 'Philippines',
          },
        }),
        200,
      );
    });
    final geocoder = NominatimCustomerReverseGeocoder(
      client,
      endpoint: Uri.parse('https://geocoder.example.test/'),
    );

    final address = await geocoder.reverse(
      const CustomerMapPoint(15.4865, 120.9734),
    );

    expect(address.street, '42 Mabini Street');
    expect(address.barangay, 'Centro');
    expect(address.city, 'Cabanatuan City');
    expect(address.province, 'Nueva Ecija');
    expect(address.postalCode, '3100');
  });
}
