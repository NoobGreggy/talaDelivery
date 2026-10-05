import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

class _FakeRealtimeSocket implements RiderRealtimeSocket {
  final handlers = <String, void Function(dynamic)>{};
  final subscriptions = <Object>[];
  void Function(dynamic)? acknowledge;
  int closes = 0, connects = 0;
  @override
  void on(String event, void Function(dynamic) handler) =>
      handlers[event] = handler;
  @override
  void emitWithAck(String event, Object data, void Function(dynamic) ack) {
    expectSync(event, 'subscribe');
    subscriptions.add(data);
    acknowledge = ack;
  }

  @override
  void connect() => connects++;
  @override
  void close() => closes++;
  void emit(String event, [dynamic data]) => handlers[event]?.call(data);
  void ready() {
    emit('connect');
    acknowledge!({'success': true});
  }
}

RiderRealtimeConfig _config() =>
    RiderRealtimeConfig(socketUrl: Uri.parse('http://localhost:3008'));
Future<void> _flush() => Future<void>.delayed(Duration.zero);
RiderRealtimeService _service(_FakeRealtimeSocket socket) =>
    RiderRealtimeService(
      config: _config(),
      readToken: () async => 'access-jwt',
      opener: (_, _) => socket,
    );

void main() {
  test(
    'JWT namespace handshake, own user room ack, and event forwarding',
    () async {
      final socket = _FakeRealtimeSocket();
      Uri? url;
      String? jwt;
      final service = RiderRealtimeService(
        config: _config(),
        readToken: () async => 'access-jwt',
        opener: (u, t) {
          url = u;
          jwt = t;
          return socket;
        },
      );
      final events = <RiderRealtimeEvent>[];
      service.events.listen(events.add);
      await service.start(userId: 9);
      expect(url.toString(), 'http://localhost:3008/realtime');
      expect(jwt, 'access-jwt');
      socket.emit('connect');
      expect(socket.subscriptions.single, {'room': 'user:9'});
      expect(service.state, RiderRealtimeState.connecting);
      socket.emit('delivery.offered', {'offerId': 30});
      await _flush();
      expect(events, isEmpty);
      socket.acknowledge!({'success': true});
      expect(service.state, RiderRealtimeState.connected);
      for (final event in [
        'delivery.offered',
        'delivery.updated',
        'offer.updated',
        'notification.created',
      ]) {
        socket.emit(event, {'id': 30});
      }
      socket.emit('delivery.updated', 'invalid payload');
      await _flush();
      expect(events.map((e) => e.name), [
        'realtime.connected',
        'delivery.offered',
        'delivery.updated',
        'offer.updated',
        'notification.created',
      ]);
      await service.stop();
      socket.emit('delivery.updated', {'id': 30});
      await _flush();
      expect(events, hasLength(5));
      expect(service.state, RiderRealtimeState.idle);
      service.dispose();
    },
  );

  testWidgets(
    'disconnect retries with fresh JWT and rejoins; stopped frames ignored',
    (tester) async {
      final sockets = <_FakeRealtimeSocket>[];
      var token = 'first';
      final service = RiderRealtimeService(
        config: _config(),
        readToken: () async => token,
        opener: (_, jwt) {
          expectSync(jwt, token);
          final s = _FakeRealtimeSocket();
          sockets.add(s);
          return s;
        },
      );
      await service.start(userId: 9);
      sockets[0].ready();
      token = 'rotated';
      sockets[0].emit('disconnect');
      expect(service.state, RiderRealtimeState.connecting);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(sockets, hasLength(2));
      sockets[0].emit('connect');
      expect(sockets[0].subscriptions, hasLength(1));
      sockets[1].ready();
      expect(service.state, RiderRealtimeState.connected);
      expect(sockets[1].subscriptions.single, {'room': 'user:9'});
      await service.stop();
      service.dispose();
    },
  );

  testWidgets(
    'subscription denial and missing acknowledgment never report connected',
    (tester) async {
      final sockets = <_FakeRealtimeSocket>[];
      final service = RiderRealtimeService(
        config: _config(),
        readToken: () async => 'jwt',
        opener: (_, _) {
          final s = _FakeRealtimeSocket();
          sockets.add(s);
          return s;
        },
      );
      await service.start(userId: 9);
      sockets[0].emit('connect');
      sockets[0].acknowledge!({'success': false});
      expect(service.state, RiderRealtimeState.connecting);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      sockets[1].emit('connect');
      await tester.pump(const Duration(seconds: 10));
      expect(sockets[1].closes, 1);
      expect(service.state, RiderRealtimeState.connecting);
      await service.stop();
      service.dispose();
    },
  );

  test('logout during token read does not open a socket', () async {
    final pending = Completer<String?>();
    var calls = 0;
    final service = RiderRealtimeService(
      config: _config(),
      readToken: () => pending.future,
      opener: (_, _) {
        calls++;
        return _FakeRealtimeSocket();
      },
    );
    final starting = service.start(userId: 9);
    await _flush();
    await service.stop();
    pending.complete('jwt');
    await starting;
    expect(calls, 0);
    service.dispose();
  });

  test(
    'switching user closes old socket and ignores stale subscription ack',
    () async {
      final sockets = <_FakeRealtimeSocket>[];
      final service = RiderRealtimeService(
        config: _config(),
        readToken: () async => 'jwt',
        opener: (_, _) {
          final s = _FakeRealtimeSocket();
          sockets.add(s);
          return s;
        },
      );
      await service.start(userId: 9);
      sockets[0].emit('connect');
      await service.start(userId: 10);
      sockets[0].acknowledge!({'success': true});
      expect(service.state, RiderRealtimeState.connecting);
      sockets[1].ready();
      expect(sockets[1].subscriptions.single, {'room': 'user:10'});
      expect(sockets[0].closes, 1);
      service.dispose();
    },
  );

  test('foreground resume reconnects and resubscribes', () async {
    final sockets = <_FakeRealtimeSocket>[];
    final service = RiderRealtimeService(
      config: _config(),
      readToken: () async => 'jwt',
      opener: (_, _) {
        final s = _FakeRealtimeSocket();
        sockets.add(s);
        return s;
      },
    );
    await service.start(userId: 9);
    sockets[0].ready();
    await service.reconnect();
    expect(sockets, hasLength(2));
    sockets[1].ready();
    expect(service.state, RiderRealtimeState.connected);
    service.dispose();
  });
  _realtimeControllerChecks();
}

class _EventControllerRepository implements RiderRepository {
  List<RiderDelivery> currentDeliveries = const [];
  int offersCalls = 0;
  int notificationsCalls = 0;
  bool offerAvailable = true;
  late RiderProfile _profile;
  final _notification = RiderNotification(
    id: 11,
    title: 'New offer nearby',
    message: 'A delivery is waiting.',
    isRead: false,
    createdAt: DateTime.now(),
  );

  _EventControllerRepository()
    : _profile = RiderProfile(
        id: 4,
        user: const RiderUser(
          id: 9,
          name: 'API Rider',
          email: 'rider@example.com',
          role: 'rider',
        ),
        vehicleType: 'BIKE',
        isOnline: false,
        status: 'OFFLINE',
        completedDeliveries: 0,
        totalEarnings: 0,
      );

  @override
  Future<RiderUser?> restoreSession() async => _profile.user;

  @override
  Future<RiderUser> login({
    required String email,
    required String password,
  }) async => _profile.user;

  @override
  Future<void> logout() async {}

  @override
  Future<RiderProfile> profile() async => _profile;

  @override
  Future<RiderEarningsSummary> earningsSummary() async {
    final now = DateTime.now();
    final period = RiderEarningsPeriod(
      start: now.subtract(const Duration(days: 7)),
      end: now,
      completedDeliveries: 0,
      earnings: 0,
    );
    return RiderEarningsSummary(
      timezone: 'Asia/Manila',
      weekType: 'ROLLING_SEVEN_DAYS',
      today: period,
      week: period,
      month: period,
    );
  }

  @override
  Future<RiderProfile> setOnline(bool online) async => _profile = RiderProfile(
    id: _profile.id,
    user: _profile.user,
    vehicleType: _profile.vehicleType,
    isOnline: online,
    status: online ? 'ONLINE' : 'OFFLINE',
    completedDeliveries: _profile.completedDeliveries,
    totalEarnings: _profile.totalEarnings,
  );

  final delivery = RiderDelivery(
    id: 8,
    status: 'UNASSIGNED',
    pickupAddress: 'A',
    deliveryAddress: 'B',
    distanceKm: 2.0,
    deliveryFee: 50,
    createdAt: DateTime.now(),
  );

  @override
  Future<List<RiderOffer>> offers() async {
    offersCalls += 1;
    return _profile.isOnline && offerAvailable
        ? [
            RiderOffer(
              id: 30,
              status: 'PENDING',
              expiresAt: DateTime.now().add(const Duration(minutes: 2)),
              delivery: delivery,
            ),
          ]
        : const [];
  }

  @override
  Future<RiderOffer> acceptOffer(int offerId) async =>
      throw UnimplementedError();

  @override
  Future<void> rejectOffer(int offerId) async {}

  @override
  Future<List<RiderDelivery>> deliveries() async => currentDeliveries;

  @override
  Future<RiderDelivery> updateDelivery(int deliveryId, String action) async =>
      delivery;

  @override
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? heading,
    double? speed,
    DateTime? recordedAt,
  }) async {}

  @override
  Future<List<RiderNotification>> notifications() async {
    notificationsCalls += 1;
    return [_notification];
  }

  @override
  Future<void> markNotificationRead(int notificationId) async {}
}

void _realtimeControllerChecks() {
  testWidgets(
    'Maps/background keeps active tracking; completion and idle pause stop it',
    (tester) async {
      final repository = _EventControllerRepository()
        ..currentDeliveries = [
          RiderDelivery.fromJson({'id': 8, 'status': 'PICKED_UP'}),
        ];
      final controller = RiderAppController(repository);
      final location = RiderLocationService(
        source: _ControllerLocationSource(),
        postLocation: (_) async {},
      );
      controller.attachLocation(location);
      await controller.restore();
      await tester.pump();
      expect(location.activeDeliveryId, 8);
      expect(location.isRunning, true);
      controller.handleAppPaused();
      expect(location.isRunning, true);
      repository.currentDeliveries = [
        RiderDelivery.fromJson({'id': 8, 'status': 'DELIVERED'}),
      ];
      await controller.refresh();
      expect(controller.activeDelivery, null);
      expect(location.isRunning, false);
      await controller.handleAppResumed();
      await controller.setOnline(true);
      expect(location.isRunning, true);
      controller.handleAppPaused();
      expect(location.isRunning, false);
      controller.dispose();
      location.dispose();
      await tester.pump();
    },
  );
  testWidgets('open delivery reflects pushed status and cancellation', (
    tester,
  ) async {
    RiderDelivery delivery(String status) => RiderDelivery(
      id: 8,
      status: status,
      pickupAddress: 'Store',
      deliveryAddress: 'Customer',
      distanceKm: 2,
      deliveryFee: 50,
      createdAt: DateTime(2026, 9, 28),
    );
    final original = delivery('ASSIGNED');
    final repository = _EventControllerRepository()
      ..currentDeliveries = [original];
    final controller = RiderAppController(repository);
    final socket = _FakeRealtimeSocket();
    final realtime = _service(socket);
    controller.attachRealtime(realtime);
    await controller.login(email: 'rider@example.com', password: 'password');
    await tester.pump();
    socket.ready();
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: RiderDependencyScope(
          dependencies: RiderAppDependencies(repository, controller),
          child: ActiveDeliveryScreen(delivery: original),
        ),
      ),
    );
    expect(find.text('Heading to store'), findsOneWidget);
    expect(find.text('Google Maps: pickup'), findsOneWidget);
    for (final status in ['ACCEPTED', 'PICKED_UP', 'CANCELLED']) {
      repository.currentDeliveries = [delivery(status)];
      socket.emit('delivery.updated', {'deliveryId': 8, 'status': status});
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          status == 'ACCEPTED'
              ? 'At the store'
              : status == 'PICKED_UP'
              ? 'Heading to customer'
              : 'cancelled',
        ),
        findsOneWidget,
      );
      if (status == 'PICKED_UP') {
        expect(find.text('Google Maps: customer'), findsOneWidget);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    realtime.dispose();
  });

  testWidgets(
    'offers, expiry, notifications refresh and fallback catches missed offers',
    (tester) async {
      final repository = _EventControllerRepository()..offerAvailable = false;
      final controller = RiderAppController(repository),
          socket = _FakeRealtimeSocket();
      final realtime = _service(socket);
      controller.attachRealtime(realtime);
      await controller.login(email: 'rider@example.com', password: 'password');
      await controller.setOnline(true);
      await tester.pump();
      socket.ready();
      await tester.pump();
      await tester.pump();
      expect(controller.offerPollInterval, const Duration(seconds: 90));
      repository.offerAvailable = true;
      socket.emit('delivery.offered', {'offerId': 30});
      await tester.pump();
      expect(controller.offers, hasLength(1));
      repository.offerAvailable = false;
      socket.emit('offer.updated', {'offerId': 30, 'status': 'EXPIRED'});
      await tester.pump();
      expect(controller.offers, isEmpty);
      final notifications = repository.notificationsCalls;
      socket.emit('notification.created', {'id': 11});
      await tester.pump();
      expect(repository.notificationsCalls, greaterThan(notifications));
      expect(controller.unreadNotificationCount, 1);
      repository.offerAvailable = true;
      await tester.pump(const Duration(seconds: 91));
      await tester.pump();
      expect(controller.offers, hasLength(1));
      controller.dispose();
      realtime.dispose();
    },
  );
}

class _ControllerLocationSource implements RiderLocationSource {
  @override
  Future<RiderLocationPermission> permissionStatus() async =>
      RiderLocationPermission.granted;
  @override
  Future<RiderLocationPermission> requestPermission() async =>
      RiderLocationPermission.granted;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<RiderLatLng?> currentPosition() async =>
      const RiderLatLng(16.94, 121.76);
}
