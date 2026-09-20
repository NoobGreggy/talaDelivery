import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tala_delivery_customer/main.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'support/customer_fakes.dart';

class _FakeSocketSink implements WebSocketSink {
  _FakeSocketSink(this.messages);

  final List<String> messages;
  bool closed = false;

  @override
  void add(Object? data) => messages.add(data.toString());

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocket implements WebSocketChannel {
  final incoming = StreamController<dynamic>.broadcast(sync: true);
  final messages = <String>[];
  late final _FakeSocketSink fakeSink = _FakeSocketSink(messages);

  @override
  Future<void> get ready async {}

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => fakeSink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  void emit(String event, {String? channel, Map<String, dynamic>? data}) {
    incoming.add(
      jsonEncode({
        'event': event,
        'channel': channel,
        'data': jsonEncode(data ?? const <String, dynamic>{}),
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    if (invocation.memberName == #read) {
      return Future<String?>.value(values[key]);
    }
    if (invocation.memberName == #write) {
      values[key!] = invocation.namedArguments[#value] as String;
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _TrackingOrders extends FakeCustomerOrderRepository {
  int fetches = 0;
  String status = 'PENDING';

  @override
  Future<CustomerOrder> get(int id) async {
    fetches++;
    return CustomerOrder(
      id: id,
      orderNumber: 'TLD-TEST-31',
      status: status,
      statusLabel: status,
      paymentMethod: 'COD',
      subtotal: 100,
      deliveryFee: 20,
      discount: 0,
      total: 120,
      deliveryAddress: '123 Example Street',
      createdAt: DateTime(2026, 9, 18),
    );
  }
}

class _ChangingNotifications extends FakeCustomerNotificationRepository {
  int fetches = 0;
  List<CustomerNotification> current = const [];

  @override
  Future<List<CustomerNotification>> list() async {
    fetches++;
    return current;
  }
}

void main() {
  test(
    'secure token store survives repository recreation and clears',
    () async {
      final storage = _FakeSecureStorage();
      await SecureCustomerTokenStore(storage).save('saved-token');
      final restored = SecureCustomerTokenStore(storage);
      expect(await restored.read(), 'saved-token');
      await restored.clear();
      expect(await SecureCustomerTokenStore(storage).read(), isNull);
    },
  );

  test(
    'authorizes own private channel and refreshes each event once',
    () async {
      final tokenStore = MemoryCustomerTokenStore();
      await tokenStore.save('customer-token');
      final sockets = <_FakeSocket>[];
      final client = MockClient((request) async {
        expect(request.url.path, '/broadcasting/auth');
        expect(request.headers['authorization'], 'Bearer customer-token');
        expect(request.bodyFields, {
          'socket_id': '123.456',
          'channel_name': 'private-user.7',
        });
        return http.Response(jsonEncode({'auth': 'public-key:signature'}), 200);
      });
      final realtime = CustomerRealtimeController(
        config: CustomerRealtimeConfig(
          socketUrl: 'ws://localhost:8080',
          appKey: 'public-key',
          authUri: Uri.parse('https://api.test/broadcasting/auth'),
        ),
        tokenStore: tokenStore,
        authClient: client,
        socketFactory: (uri) {
          expect(uri.path, '/app/public-key');
          expect(uri.queryParameters['protocol'], '7');
          final socket = _FakeSocket();
          sockets.add(socket);
          return socket;
        },
      );

      await realtime.start(7);
      final socket = sockets.single;
      socket.emit(
        'pusher:connection_established',
        data: {'socket_id': '123.456'},
      );
      await Future<void>.delayed(Duration.zero);
      expect(jsonDecode(socket.messages.single), {
        'event': 'pusher:subscribe',
        'data': {'channel': 'private-user.7', 'auth': 'public-key:signature'},
      });

      socket.emit(
        'pusher_internal:subscription_succeeded',
        channel: 'private-user.7',
      );
      expect(realtime.isSubscribed, isTrue);
      final initialOrders = realtime.orderVersion;
      final initialNotifications = realtime.notificationVersion;
      const order = <String, dynamic>{
        'id': 31,
        'status': 'CONFIRMED',
        'updated_at': '2026-09-18T01:00:00Z',
      };
      socket.emit('order.updated', channel: 'private-user.8', data: order);
      socket.emit('order.updated', channel: 'private-user.7', data: order);
      socket.emit('order.updated', channel: 'private-user.7', data: order);
      expect(realtime.orderVersion, initialOrders + 1);
      expect(realtime.lastOrderId, 31);

      socket.emit(
        'notification.created',
        channel: 'private-user.7',
        data: {'id': 99},
      );
      socket.emit(
        'notification.created',
        channel: 'private-user.7',
        data: {'id': 99},
      );
      expect(realtime.notificationVersion, initialNotifications + 1);

      realtime.pause();
      expect(socket.fakeSink.closed, isTrue);
      realtime.resume();
      await Future<void>.delayed(Duration.zero);
      expect(sockets, hasLength(2));
      realtime.stop();
      expect(sockets.last.fakeSink.closed, isTrue);
      expect(realtime.isSubscribed, isFalse);
      realtime.dispose();
      client.close();
      for (final value in sockets) {
        await value.incoming.close();
      }
    },
  );

  testWidgets('order tracking refetches the order on its broadcast', (
    tester,
  ) async {
    final tokenStore = MemoryCustomerTokenStore();
    await tokenStore.save('customer-token');
    final socket = _FakeSocket();
    final realtime = CustomerRealtimeController(
      config: CustomerRealtimeConfig(
        socketUrl: 'ws://localhost:8080',
        appKey: 'public-key',
        authUri: Uri.parse('https://api.test/broadcasting/auth'),
      ),
      tokenStore: tokenStore,
      authClient: MockClient(
        (_) async => http.Response(jsonEncode({'auth': 'key:signature'}), 200),
      ),
      socketFactory: (_) => socket,
    );
    await realtime.start(7);
    socket.emit(
      'pusher:connection_established',
      data: {'socket_id': '123.456'},
    );
    await tester.pump();
    socket.emit(
      'pusher_internal:subscription_succeeded',
      channel: 'private-user.7',
    );

    final orders = _TrackingOrders();
    final dependencies = CustomerAppDependencies(
      FakeCustomerAuthRepository(),
      FakeCustomerAddressRepository(),
      FakeCustomerCatalogRepository(),
      orders,
      FakeCustomerNotificationRepository(),
      CustomerCartController(),
      null,
      realtime,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDependencyScope(
          dependencies: dependencies,
          child: const OrderTrackingPage(orderId: 31),
        ),
      ),
    );
    await tester.pump();
    expect(orders.fetches, 1);

    await tester.pump(const Duration(seconds: 45));
    expect(orders.fetches, 1);

    orders.status = 'CONFIRMED';
    socket.emit(
      'order.updated',
      channel: 'private-user.7',
      data: {
        'id': 31,
        'status': 'CONFIRMED',
        'updated_at': '2026-09-18T01:00:00Z',
      },
    );
    await tester.pump();
    expect(orders.fetches, 2);
    await tester.pump();
    expect(find.text('Store confirmed'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
    await socket.incoming.close();
  });

  testWidgets('notification broadcast updates the home unread badge', (
    tester,
  ) async {
    final tokenStore = MemoryCustomerTokenStore();
    await tokenStore.save('customer-token');
    final socket = _FakeSocket();
    final realtime = CustomerRealtimeController(
      config: CustomerRealtimeConfig(
        socketUrl: 'ws://localhost:8080',
        appKey: 'public-key',
        authUri: Uri.parse('https://api.test/broadcasting/auth'),
      ),
      tokenStore: tokenStore,
      authClient: MockClient(
        (_) async => http.Response(jsonEncode({'auth': 'key:signature'}), 200),
      ),
      socketFactory: (_) => socket,
    );
    await realtime.start(7);
    socket.emit(
      'pusher:connection_established',
      data: {'socket_id': '123.456'},
    );
    await tester.pump();
    socket.emit(
      'pusher_internal:subscription_succeeded',
      channel: 'private-user.7',
    );

    final notifications = _ChangingNotifications();
    final dependencies = CustomerAppDependencies(
      FakeCustomerAuthRepository(),
      FakeCustomerAddressRepository(),
      FakeCustomerCatalogRepository(),
      FakeCustomerOrderRepository(),
      notifications,
      CustomerCartController(),
      null,
      realtime,
    );
    final routes = CustomerRouteController(
      CustomerSession(
        isRestoring: false,
        isAuthenticated: true,
        role: CustomerUserRole.customer,
        hasDeliveryAddress: true,
        user: const CustomerUser(
          id: 7,
          name: 'Test Customer',
          email: 'customer@example.test',
          role: 'customer',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDependencyScope(
          dependencies: dependencies,
          child: CustomerRouteScope(
            controller: routes,
            child: const Scaffold(body: HomePage()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(notifications.fetches, 1);

    notifications.current = const [
      CustomerNotification(
        id: 99,
        type: 'order.status',
        title: 'Order updated',
        messageText: 'Your order changed.',
        isRead: false,
      ),
    ];
    socket.emit(
      'notification.created',
      channel: 'private-user.7',
      data: {'id': 99},
    );
    await tester.pump();
    await tester.pump();
    expect(notifications.fetches, 2);
    final badge = find.byKey(const Key('home-unread-badge'));
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
    await socket.incoming.close();
  });
}
