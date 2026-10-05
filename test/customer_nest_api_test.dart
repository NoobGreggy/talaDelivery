import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_customer/main.dart';

void main() {
  test(
    'delivery quote requests the server fee for the selected store and address',
    () async {
      final tokens = MemoryCustomerTokenStore();
      await tokens.save('customer-token');
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/orders/delivery-quote');
        expect(request.headers['authorization'], 'Bearer customer-token');
        expect(jsonDecode(request.body), {
          'storeId': 1,
          'deliveryLatitude': '14.557',
          'deliveryLongitude': '121.027',
          'city': 'Makati City',
          'province': 'Metro Manila',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'deliveryFee': '49.00',
              'distanceKm': '0.39',
              'zone': {'id': 1, 'name': 'Makati Zone'},
            },
          }),
          201,
        );
      });
      final api = CustomerApiClient(
        client,
        CustomerApiConfig(baseUrl: 'http://api.test/api/v1/', apiKey: 'test'),
        tokens,
      );
      final quote = await ApiCustomerOrderRepository(api).quoteDelivery(
        store: const StoreData(id: 1, name: 'Test Store', status: 'ACTIVE'),
        address: const CustomerAddress(
          id: 1,
          recipientName: 'Customer',
          phone: '09123456789',
          addressLine: 'Street',
          city: 'Makati City',
          province: 'Metro Manila',
          latitude: 14.557,
          longitude: 121.027,
          isDefault: true,
        ),
      );
      expect(quote.deliveryFee, 49);
      expect(quote.zoneName, 'Makati Zone');
      expect(
        () => CustomerDeliveryQuote.fromJson({
          'deliveryFee': 'NaN',
          'distanceKm': '1',
          'zone': {},
        }),
        throwsA(isA<CustomerApiException>()),
      );
      client.close();
    },
  );
  test(
    'Nest store detail loads its product categories and every product page',
    () async {
      final client = MockClient((request) async {
        dynamic data;
        switch (request.url.path) {
          case '/api/v1/stores/3':
            data = {
              'id': 3,
              'name': 'Test Store',
              'status': 'ACTIVE',
              'categories': [],
            };
          case '/api/v1/stores/3/categories':
            data = [
              {'id': 7, 'storeId': 3, 'name': 'Meals'},
            ];
          case '/api/v1/products':
            expect(request.url.queryParameters['store_id'], '3');
            final page = int.parse(request.url.queryParameters['page']!);
            data = {
              'data': [
                {
                  'id': 10 + page,
                  'storeId': 3,
                  'categoryId': 7,
                  'name': 'Sample item $page',
                  'price': '99.00',
                  'stock': 50,
                  'isAvailable': true,
                },
              ],
              'meta': {'last_page': 2},
            };
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      final api = CustomerApiClient(
        client,
        CustomerApiConfig(baseUrl: 'http://api.test/api/v1/', apiKey: 'test'),
        MemoryCustomerTokenStore(),
      );
      final store = await ApiCustomerCatalogRepository(api).getStore(3);
      expect(store.products.map((product) => product.id), [11, 12]);
      expect(
        store.products.every(
          (product) => product.available && product.storeId == 3,
        ),
        isTrue,
      );
      expect(store.categories.single.id, 7);
      client.close();
    },
  );
  test('API category keys render the exact Flutter icons and hide inactive categories', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/store-categories');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 1,
              'name': 'Custom name',
              'icon': 'medication_rounded',
              'is_active': true,
            },
            {
              'id': 2,
              'name': 'Hidden',
              'icon': 'restaurant_rounded',
              'is_active': false,
            },
          ],
        }),
        200,
      );
    });
    final api = CustomerApiClient(
      client,
      CustomerApiConfig(baseUrl: 'http://api.test/api/v1/', apiKey: 'test'),
      MemoryCustomerTokenStore(),
    );
    final categories = await ApiCustomerCatalogRepository(api).listCategories();
    expect(categories, hasLength(1));
    expect(categories.single.materialIcon, Icons.medication_rounded);
    expect(
      CategoryData.fromJson({'id': 3, 'name': 'Unknown', 'icon': 'future_icon'})
          .materialIcon,
      isNull,
    );
    client.close();
  });

  test('checkout sends Nest camelCase and parses its order response', () async {
    final tokens = MemoryCustomerTokenStore();
    await tokens.save('test-token');
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/orders');
      expect(request.headers['authorization'], 'Bearer test-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['storeId'], 3);
      expect(body['items'], [
        {'productId': 11, 'quantity': 2},
      ]);
      expect(body['deliveryLatitude'], '14.5');
      expect(body['deliveryLongitude'], '121.0');
      expect(body['notes'], 'Call first');
      expect(body.containsKey('store_id'), isFalse);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 31,
            'orderNumber': 'TLD-31',
            'status': 'PENDING',
            'storeId': 3,
            'storeName': 'Shop',
            'subtotal': '250.00',
            'deliveryFee': '20.00',
            'total': '270.00',
            'customerName': 'Customer',
            'customerPhone': '09123456789',
            'deliveryAddress': 'Street',
            'createdAt': '2026-10-05T00:00:00Z',
            'items': [
              {
                'id': 1,
                'productId': 11,
                'productName': 'Item',
                'quantity': 2,
                'unitPrice': '125.00',
                'subtotal': '250.00',
              },
            ],
          },
        }),
        201,
      );
    });
    final api = CustomerApiClient(
      client,
      CustomerApiConfig(baseUrl: 'http://api.test/api/v1/', apiKey: 'test'),
      tokens,
    );
    final order = await ApiCustomerOrderRepository(api).create(
      store: const StoreData(id: 3, name: 'Shop', status: 'ACTIVE'),
      lines: [
        CustomerCartLine(
          product: const ProductData(
            id: 11,
            storeId: 3,
            name: 'Item',
            price: 125,
            stock: 10,
            available: true,
          ),
          quantity: 2,
        ),
      ],
      address: const CustomerAddress(
        id: 1,
        recipientName: 'Customer',
        phone: '09123456789',
        addressLine: 'Street',
        city: 'City',
        province: 'Province',
        latitude: 14.5,
        longitude: 121,
        isDefault: true,
      ),
      notes: ' Call first ',
    );
    expect(order.orderNumber, 'TLD-31');
    expect(order.deliveryFee, 20);
    expect(order.items.single.name, 'Item');
    client.close();
  });
}
