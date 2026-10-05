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
  Completer<void>? pending;

  @override
  Future<CustomerOrder> get(int id) async {
    fetches++;
    final fetchedStatus = status;
    await pending?.future;
    return CustomerOrder(
      id: id,
      orderNumber: 'TLD-TEST-31',
      status: fetchedStatus,
      statusLabel: fetchedStatus,
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
  test('Nest Socket.IO authenticates, subscribes and refreshes customer events', () async {
    final tokens = MemoryCustomerTokenStore();
    await tokens.save('customer-token');
    final socket = _FakeSocket();
    final client = MockClient(
      (_) async => throw StateError('No legacy auth request expected'),
    );
    final realtime = CustomerRealtimeController(
      config: CustomerRealtimeConfig(
        socketUrl: 'http://192.168.100.18:3008',
        appKey: '',
        authUri: Uri.parse('http://192.168.100.18:3000/api/v1/'),
        socketIo: true,
      ),
      tokenStore: tokens,
      authClient: client,
      socketFactory: (uri) {
        expect(uri.scheme, 'ws');
        expect(uri.path, '/socket.io/');
        expect(uri.queryParameters['EIO'], '4');
        return socket;
      },
    );
    await realtime.start(7);
    socket.incoming.add(
      '0{"sid":"test","pingInterval":25000,"pingTimeout":20000}',
    );
    expect(socket.messages.last, '40/realtime,{"token":"customer-token"}');
    socket.incoming.add('40/realtime,{"sid":"namespace"}');
    expect(
      socket.messages.last,
      '42/realtime,1["subscribe",{"room":"user:7"}]',
    );
    socket.incoming.add(
      '43/realtime,1[{"success":true,"data":{"success":true}}]',
    );
    expect(realtime.isSubscribed, isTrue);
    final version = realtime.orderVersion;
    socket.incoming.add(
      '42/realtime,["order.updated",{"orderId":31,"status":"CONFIRMED","updatedAt":"2026-10-05"}]',
    );
    expect(realtime.lastOrderId, 31);
    expect(realtime.orderVersion, version + 1);
    final notifications = realtime.notificationVersion;
    socket.incoming.add('42/realtime,["notification.created",{"id":99}]');
    expect(realtime.notificationVersion, notifications + 1);
    realtime.watchDelivery(22);
    expect(
      socket.messages.last,
      '42/realtime,2["subscribe",{"room":"delivery:22"}]',
    );
    void location(
      int id,
      String timestamp, {
      Object latitude = 16.94,
    }) => socket.incoming.add(
      '42/realtime,${jsonEncode([
        'rider.location',
        {'deliveryId': id, 'riderId': 4, 'latitude': latitude, 'longitude': 121.76, 'timestamp': timestamp, 'accuracyM': 7},
      ])}',
    );
    location(22, '2026-10-06T01:00:00Z');
    expect(
      realtime.lastRiderLocation,
      isNull,
    ); // Wait for authorized room acknowledgment.
    socket.incoming.add('43/realtime,2[{"data":{"success":true}}]');
    expect(realtime.isDeliverySubscribed, true);
    location(22, '2026-10-06T01:00:00Z');
    expect(realtime.lastRiderLocation?.deliveryId, 22);
    expect(realtime.lastRiderLocation?.accuracy, 7);
    final locationVersion = realtime.locationVersion;
    location(99, '2026-10-06T01:00:05Z');
    location(22, '2026-10-06T00:59:00Z');
    location(22, '2026-10-06T01:00:05Z', latitude: 'invalid');
    expect(realtime.locationVersion, locationVersion);
    location(22, '2026-10-06T01:00:05Z', latitude: 16.95);
    expect(realtime.locationVersion, locationVersion + 1);
    expect(realtime.lastRiderLocation?.latitude, 16.95);
    realtime.watchDelivery(null);
    expect(realtime.lastRiderLocation, isNull);
    socket.incoming.add('2');
    expect(socket.messages.last, '3');
    realtime.dispose();
    client.close();
    await socket.incoming.close();
  });
  testWidgets('retries when a socket connects but never subscribes', (
    tester,
  ) async {
    final tokens = MemoryCustomerTokenStore();
    await tokens.save('customer-token');
    final sockets = <_FakeSocket>[];
    final client = MockClient(
      (_) async => http.Response('{"auth":"signature"}', 200),
    );
    final realtime = CustomerRealtimeController(
      config: CustomerRealtimeConfig(
        socketUrl: 'ws://localhost:6001',
        appKey: 'public-key',
        authUri: Uri.parse('https://api.test/broadcasting/auth'),
      ),
      tokenStore: tokens,
      authClient: client,
      socketFactory: (_) {
        final socket = _FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );
    await realtime.start(7);
    sockets.single.emit(
      'pusher:connection_established',
      data: {'socket_id': '1.1'},
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(sockets.single.fakeSink.closed, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(sockets, hasLength(2));
    sockets.last.emit(
      'pusher:connection_established',
      data: {'socket_id': '1.2'},
    );
    await tester.pump();
    sockets.last.emit(
      'pusher_internal:subscription_succeeded',
      channel: 'private-user.7',
    );
    final version = realtime.orderVersion;
    await tester.pump(const Duration(seconds: 16));
    expect(realtime.isSubscribed, isTrue);
    expect(sockets, hasLength(2));
    expect(version, 1);
    realtime.dispose();
    client.close();
    for (final socket in sockets) {
      await socket.incoming.close();
    }
  });

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

  test(
    'delivery channel publishes newer rider locations without order reload',
    () async {
      final tokenStore = MemoryCustomerTokenStore();
      await tokenStore.save('customer-token');
      final socket = _FakeSocket();
      final authorizedChannels = <String>[];
      final client = MockClient((request) async {
        authorizedChannels.add(request.bodyFields['channel_name']!);
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
        socketFactory: (_) => socket,
      );

      await realtime.start(7);
      socket.emit(
        'pusher:connection_established',
        data: {'socket_id': '123.456'},
      );
      await Future<void>.delayed(Duration.zero);
      realtime.watchDelivery(12);
      await Future<void>.delayed(Duration.zero);
      expect(
        authorizedChannels,
        containsAll(['private-user.7', 'private-delivery.12']),
      );

      socket.emit(
        'pusher_internal:subscription_succeeded',
        channel: 'private-delivery.12',
      );
      socket.emit(
        'rider.location.updated',
        channel: 'private-delivery.12',
        data: {
          'delivery_id': 12,
          'rider_id': 9,
          'latitude': 14.5995,
          'longitude': 120.9842,
          'sequence': 20,
          'recorded_at': '2026-09-24T10:20:30Z',
        },
      );
      final acceptedVersion = realtime.locationVersion;
      expect(realtime.lastRiderLocation?.latitude, 14.5995);

      socket.emit(
        'rider.location.updated',
        channel: 'private-delivery.12',
        data: {
          'delivery_id': 12,
          'latitude': 1,
          'longitude': 1,
          'sequence': 19,
        },
      );
      expect(realtime.locationVersion, acceptedVersion);
      expect(realtime.lastRiderLocation?.latitude, 14.5995);

      realtime.dispose();
      client.close();
      await socket.incoming.close();
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

    for (final status in [
      'CONFIRMED',
      'PREPARING',
      'READY',
      'RIDER_ASSIGNED',
    ]) {
      final before = orders.fetches;
      orders.status = status;
      orders.pending = Completer<void>();
      socket.emit(
        'order.updated',
        channel: 'private-user.7',
        data: {
          'id': 31,
          'status': status,
          'updated_at': '2026-09-18T01:00:00Z',
        },
      );
      await tester.pump();
      expect(find.byType(TrackingHero), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      orders.pending!.complete();
      orders.pending = null;
      await tester.pump();
      await tester.pump();
      expect(orders.fetches, before + 1);
      expect(
        tester.widget<TrackingHero>(find.byType(TrackingHero)).stage,
        stageForStatus(status),
      );
    }

    final beforeDelivery = orders.fetches;
    socket.emit(
      'delivery.updated',
      channel: 'private-user.7',
      data: {'id': 12, 'order_id': 31, 'status': 'ACCEPTED'},
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(orders.fetches, beforeDelivery + 1);

    socket.emit(
      'delivery.updated',
      channel: 'private-user.7',
      data: {'id': 99, 'order_id': 44, 'status': 'ACCEPTED'},
    );
    await tester.pump();
    expect(orders.fetches, beforeDelivery + 1);

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
    await tester.pumpAndSettle();
    expect(notifications.fetches, 2);
    final badge = find.byKey(const Key('home-unread-badge'));
    expect(badge, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
    await socket.incoming.close();
  });
}
