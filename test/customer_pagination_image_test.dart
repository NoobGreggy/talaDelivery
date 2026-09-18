import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_customer/main.dart';

void main() {
  test(
    'catalog continues beyond the first page and deduplicates IDs',
    () async {
      final requestedPages = <String>[];
      final client = MockClient((request) async {
        final page = request.url.queryParameters['page']!;
        requestedPages.add(page);
        final ids = page == '1' ? [1, 2] : [2, 3];
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'data': [
                for (final id in ids)
                  {'id': id, 'name': 'Store $id', 'status': 'ACTIVE'},
              ],
              'meta': {'current_page': int.parse(page), 'last_page': 2},
            },
          }),
          200,
        );
      });
      final repository = ApiCustomerCatalogRepository(
        CustomerApiClient(
          client,
          CustomerApiConfig(
            baseUrl: 'https://api.test/api/v1/',
            apiKey: 'test-key',
          ),
          MemoryCustomerTokenStore(),
        ),
      );

      final stores = await repository.listStores();
      expect(requestedPages, ['1', '2']);
      expect(stores.map((store) => store.id), [1, 2, 3]);
      client.close();
    },
  );

  testWidgets('product imagery displays supported data and falls back', (
    tester,
  ) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9S9z4ZsAAAAASUVORK5CYII=';
    const product = ProductData(
      id: 11,
      storeId: 2,
      name: 'Test product',
      price: 25,
      stock: 2,
      available: true,
      image: 'data:image/png;base64,$png',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProductArtwork(product: product)),
      ),
    );
    expect(find.byKey(const ValueKey('product-image-11')), findsOneWidget);

    const invalid = ProductData(
      id: 12,
      storeId: 2,
      name: 'Invalid image',
      price: 25,
      stock: 2,
      available: true,
      image: 'data:image/svg+xml;base64,not-a-raster',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProductArtwork(product: invalid)),
      ),
    );
    expect(find.byType(StoreArtwork), findsOneWidget);
  });
}
