import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_rider/main.dart';

ApiRiderRepository repository(
  Future<http.Response> Function(http.Request) handler,
) {
  final tokens = MemoryRiderTokenStore();
  // Opaque test tokens do not trigger JWT refresh.
  tokens.save('test-token');
  return ApiRiderRepository(
    RiderApiClient(
      MockClient(handler),
      RiderApiConfig(baseUrl: 'http://localhost:3000/api/v1/', apiKey: 'test'),
      tokens,
    ),
    tokens,
  );
}

http.Response balance() => http.Response(
  jsonEncode({
    'success': true,
    'data': {'available_tokens': '1250.50'},
  }),
  200,
);
http.Response history({int page = 1, int lastPage = 1, bool empty = false}) =>
    http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'data': empty
              ? []
              : [
                  {
                    'id': page,
                    'type': page == 1 ? 'TOP_UP' : 'DELIVERY_DEDUCTION',
                    'amount': page == 1 ? '10.00' : '-5.00',
                    'balance_after': '1250.50',
                    'delivery_id': page == 1 ? null : 9,
                    'created_at': '2026-10-06T12:45:00Z',
                  },
                ],
          'meta': {'last_page': lastPage, 'total': empty ? 0 : lastPage},
        },
      }),
      200,
    );

void main() {
  test(
    'coin formatting preserves precision, groups numbers and handles negatives',
    () {
      expect(riderCoins('1250.50'), '1,250.50');
      expect(riderCoins('-9999999999.29'), '-9,999,999,999.29');
      expect(riderCoins('0'), '0.00');
      expect(riderCoins('invalid'), 'Unavailable');
    },
  );
  test(
    'refresh is read-only and pagination deduplicates ledger entries',
    () async {
      final requests = <http.Request>[];
      final repo = repository((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/wallet')) return balance();
        return history(
          page: int.parse(request.url.queryParameters['page']!),
          lastPage: 2,
        );
      });
      final controller = RiderWalletController(repo);
      await controller.refresh();
      expect(controller.wallet!.availableTokens, '1250.50');
      expect(controller.hasMore, isTrue);
      await controller.loadMore();
      expect(controller.transactions.map((t) => t.id), [1, 2]);
      expect(controller.transactions.last.isDebit, isTrue);
      expect(controller.hasMore, isFalse);
      await controller.refresh();
      expect(controller.transactions.length, 1);
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer test-token',
        ),
        isTrue,
      );
      controller.dispose();
    },
  );
  test('balance failure keeps history and can retry; history failure keeps balance', () async {
    var failBalance = true;
    var failHistory = false;
    final controller = RiderWalletController(
      repository((request) async {
        if (request.url.path.endsWith('/wallet')) {
          return failBalance ? http.Response('{}', 503) : balance();
        }
        return failHistory ? http.Response('{}', 503) : history();
      }),
    );
    await controller.refresh();
    expect(controller.error, isNotNull);
    expect(controller.transactions.length, 1);
    failBalance = false;
    await controller.refresh();
    expect(controller.error, isNull);
    expect(controller.wallet, isNotNull);
    failHistory = true;
    await controller.refresh();
    expect(controller.historyError, isNotNull);
    expect(controller.wallet, isNotNull);
    expect(controller.transactions.length, 1);
    controller.dispose();
  });
  test('concurrent refreshes do not issue duplicate requests', () async {
    final gate = Completer<void>();
    var calls = 0;
    final controller = RiderWalletController(
      repository((request) async {
        calls++;
        await gate.future;
        return request.url.path.endsWith('/wallet') ? balance() : history();
      }),
    );
    final pending = controller.refresh();
    await controller.refresh();
    gate.complete();
    await pending;
    expect(calls, 2);
    controller.dispose();
  });
  test('wallet route requires an authenticated rider', () {
    final routes = RiderRouteController(RiderSession(isRestoring: false));
    expect(routes.guardLocation(RiderRoutes.wallet), RiderRoutes.login);
    routes.signInAsRider();
    expect(routes.guardLocation(RiderRoutes.wallet), RiderRoutes.wallet);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'wallet renders credits, debits, pagination and refresh in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        var calls = 0;
        final repo = repository((request) async {
          calls++;
          return request.url.path.endsWith('/wallet')
              ? balance()
              : history(
                  page: int.parse(request.url.queryParameters['page']!),
                  lastPage: 2,
                );
        });
        final dependencies = RiderAppDependencies(
          repo,
          RiderAppController(repo),
        );
        await tester.pumpWidget(
          RiderDependencyScope(
            dependencies: dependencies,
            child: MaterialApp(
              theme: buildRiderTheme(
                dark ? RiderPalette.dark : RiderPalette.light,
              ),
              home: const RiderWalletScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1,250.50'), findsOneWidget);
        expect(find.text('+10.00 coins'), findsOneWidget);
        await tester.ensureVisible(find.text('Load more'));
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
        expect(find.text('-5.00 coins'), findsOneWidget);
        expect(find.text('Delivery #9'), findsOneWidget);
        expect(find.text('Load more'), findsNothing);
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await tester.pumpAndSettle();
        expect(calls, greaterThanOrEqualTo(5));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        dependencies.dispose();
      },
    );
  }
  testWidgets('wallet shows loading, error retry and empty state', (
    tester,
  ) async {
    final gate = Completer<void>();
    var fail = true;
    final repo = repository((request) async {
      await gate.future;
      if (fail) return http.Response('{}', 503);
      return request.url.path.endsWith('/wallet')
          ? balance()
          : history(empty: true);
    });
    final dependencies = RiderAppDependencies(repo, RiderAppController(repo));
    await tester.pumpWidget(
      RiderDependencyScope(
        dependencies: dependencies,
        child: MaterialApp(
          theme: buildRiderTheme(RiderPalette.light),
          home: const RiderWalletScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsWidgets);
    fail = false;
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();
    expect(find.text('No wallet activity yet'), findsOneWidget);
    expect(find.text('1,250.50'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    dependencies.dispose();
  });
}
