import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_customer/main.dart';

void main() {
  group('customer Laravel API integration', () {
    test('login stores the token used to create an address', () async {
      var requestNumber = 0;
      final client = MockClient((request) async {
        requestNumber++;
        expect(request.headers['x-app-key'], 'test-app-key');

        if (requestNumber == 1) {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/auth/login');
          expect(jsonDecode(request.body), {
            'email': 'customer@example.com',
            'password': 'password123',
          });
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Login successful.',
              'data': {
                'token': 'sanctum-token',
                'user': {
                  'id': 7,
                  'name': 'Customer',
                  'email': 'customer@example.com',
                  'phone': null,
                  'role': 'customer',
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/addresses');
        expect(request.headers['authorization'], 'Bearer sanctum-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['recipient_name'], 'Juan Dela Cruz');
        expect(body['city'], 'Cabanatuan City');
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Address created.',
            'data': {
              'id': 12,
              'label': 'Home',
              'recipient_name': 'Juan Dela Cruz',
              'phone': '09171234567',
              'address_line': '123 Example Street',
              'barangay': null,
              'city': 'Cabanatuan City',
              'province': 'Nueva Ecija',
              'notes': null,
              'is_default': true,
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final tokenStore = MemoryCustomerTokenStore();
      final apiClient = CustomerApiClient(
        client,
        CustomerApiConfig(
          baseUrl: 'https://api.example.test/api/v1/',
          apiKey: 'test-app-key',
        ),
        tokenStore,
      );
      final authRepository = ApiCustomerAuthRepository(apiClient, tokenStore);
      final addressRepository = ApiCustomerAddressRepository(apiClient);

      final user = await authRepository.login(
        email: 'customer@example.com',
        password: 'password123',
      );
      final address = await addressRepository.create(
        const CustomerAddressRequest(
          label: 'Home',
          recipientName: 'Juan Dela Cruz',
          phone: '09171234567',
          addressLine: '123 Example Street',
          city: 'Cabanatuan City',
          province: 'Nueva Ecija',
          isDefault: true,
        ),
      );

      expect(user.role, 'customer');
      expect(address.id, 12);
      expect(requestNumber, 2);
    });

    test('maps Laravel validation errors to fields', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'The email field must be a valid email address.',
            'errors': {
              'email': ['The email field must be a valid email address.'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );
      final tokenStore = MemoryCustomerTokenStore();
      final repository = ApiCustomerAuthRepository(
        CustomerApiClient(
          client,
          CustomerApiConfig(
            baseUrl: 'https://api.example.test/api/v1/',
            apiKey: 'test-app-key',
          ),
          tokenStore,
        ),
        tokenStore,
      );
      final viewModel = CustomerAuthViewModel(repository);

      final user = await viewModel.login(
        email: 'invalid',
        password: 'password123',
      );

      expect(user, isNull);
      expect(
        viewModel.fieldError('email'),
        'The email field must be a valid email address.',
      );
    });

    test(
      'catalog repository maps Laravel stores and decimal products',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/stores/3');
          expect(request.headers['x-app-key'], 'test-app-key');
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Store retrieved.',
              'data': {
                'id': 3,
                'name': 'API Store',
                'status': 'ACTIVE',
                'description': 'Real store data',
                'products': [
                  {
                    'id': 11,
                    'store_id': 3,
                    'category_id': null,
                    'name': 'API Product',
                    'description': null,
                    'price': '125.50',
                    'stock': 4,
                    'is_available': true,
                  },
                ],
              },
            }),
            200,
          );
        });
        final repository = ApiCustomerCatalogRepository(
          CustomerApiClient(
            client,
            CustomerApiConfig(
              baseUrl: 'https://api.example.test/api/v1/',
              apiKey: 'test-app-key',
            ),
            MemoryCustomerTokenStore(),
          ),
        );

        final store = await repository.getStore(3);

        expect(store.name, 'API Store');
        expect(store.products.single.price, 125.5);
        expect(store.products.single.available, isTrue);
      },
    );

    test('address update and delete use protected Laravel routes', () async {
      var requestNumber = 0;
      final client = MockClient((request) async {
        requestNumber++;
        expect(request.headers['authorization'], 'Bearer sanctum-token');
        if (requestNumber == 1) {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/v1/addresses/12');
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Address updated.',
              'data': {
                'id': 12,
                'label': 'Home',
                'recipient_name': 'Customer',
                'phone': '09171234567',
                'address_line': '45 Mabini Street',
                'barangay': null,
                'city': 'Cabanatuan City',
                'province': 'Nueva Ecija',
                'postal_code': null,
                'latitude': null,
                'longitude': null,
                'notes': null,
                'is_default': true,
              },
            }),
            200,
          );
        }
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/addresses/12');
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Address deleted.',
            'data': null,
          }),
          200,
        );
      });
      final tokenStore = MemoryCustomerTokenStore()..save('sanctum-token');
      final repository = ApiCustomerAddressRepository(
        CustomerApiClient(
          client,
          CustomerApiConfig(
            baseUrl: 'https://api.example.test/api/v1/',
            apiKey: 'test-app-key',
          ),
          tokenStore,
        ),
      );
      const request = CustomerAddressRequest(
        label: 'Home',
        recipientName: 'Customer',
        phone: '09171234567',
        addressLine: '45 Mabini Street',
        city: 'Cabanatuan City',
        province: 'Nueva Ecija',
        isDefault: true,
      );

      final address = await repository.update(12, request);
      await repository.delete(12);

      expect(address.addressLine, '45 Mabini Street');
      expect(requestNumber, 2);
    });
  });

  group('CustomerValidators', () {
    test('validates email, password, phone, and confirmation', () {
      expect(CustomerValidators.email('invalid'), isNotNull);
      expect(CustomerValidators.email('customer@example.com'), isNull);
      expect(CustomerValidators.password('short'), isNotNull);
      expect(CustomerValidators.password('password123'), isNull);
      expect(CustomerValidators.phone('123'), isNotNull);
      expect(CustomerValidators.phone('0917 123 4567'), isNull);
      expect(
        CustomerValidators.confirmPassword('different', 'password123'),
        isNotNull,
      );
      expect(
        CustomerValidators.confirmPassword('password123', 'password123'),
        isNull,
      );
    });
  });
}
