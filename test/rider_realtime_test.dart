import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

class _FakeRealtimeSocket implements RiderRealtimeSocket {
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();
  final List<Object> sent = <Object>[];
  int closes = 0;

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  void send(Object data) => sent.add(data);

  @override
  Future<void> close() async {
    closes += 1;
    await _controller.close();
  }

  void emit(Object message) => _controller.add(message);

  void closeStream() => _controller.close();
}

class _RecordingAuthenticator implements RiderChannelAuthenticator {
  String? channelName;
  String? socketId;
  int calls = 0;
  RiderChannelAuthResult result = const RiderChannelAuthResult(
    auth: 'signed-token',
  );

  @override
  Future<RiderChannelAuthResult> authenticateChannel({
    required String channelName,
    required String socketId,
  }) async {
    calls += 1;
    this.channelName = channelName;
    this.socketId = socketId;
    return result;
  }
}

RiderRealtimeConfig _config() => RiderRealtimeConfig(
  socketUrl: Uri.parse('ws://localhost:8080'),
  appKey: 'public-key',
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'connects, authenticates, and subscribes to the private user channel',
    () async {
      final authenticator = _RecordingAuthenticator();
      final socket = _FakeRealtimeSocket();
      var openerCalls = 0;
      Uri? openedUrl;
      final realtime = RiderRealtimeService(
        config: _config(),
        authenticator: authenticator,
        opener: (url) {
          openerCalls += 1;
          openedUrl = url;
          return socket;
        },
      );

      await realtime.start(userId: 5);
      expect(openerCalls, 1);
      expect(openedUrl!.path, '/app/public-key');

      socket.emit(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '123.456'}),
        }),
      );
      await _flush();

      expect(authenticator.channelName, 'private-user.5');
      expect(authenticator.socketId, '123.456');
      final subscribeMessage = socket.sent.last as Map<String, dynamic>;
      expect(subscribeMessage['event'], 'pusher:subscribe');
      final subscribeData = subscribeMessage['data'] as Map<String, dynamic>;
      expect(subscribeData['channel'], 'private-user.5');
      expect(subscribeData['auth'], 'signed-token');

      socket.emit(
        jsonEncode({
          'event': 'pusher_internal:subscription_succeeded',
          'channel': 'private-user.99',
          'data': '{}',
        }),
      );
      await _flush();
      expect(realtime.state, RiderRealtimeState.connecting);

      socket.emit(
        jsonEncode({
          'event': 'pusher_internal:subscription_succeeded',
          'channel': 'private-user.5',
          'data': '{}',
        }),
      );
      await _flush();
      expect(realtime.state, RiderRealtimeState.connected);

      socket.emit(jsonEncode({'event': 'pusher:ping', 'data': '{}'}));
      await _flush();
      expect(
        (socket.sent.last as Map<String, dynamic>)['event'],
        'pusher:pong',
      );

      await realtime.stop();
      expect(realtime.state, RiderRealtimeState.idle);
      expect(socket.closes, greaterThanOrEqualTo(1));
    },
  );

  test(
    'does not subscribe when the backend rejects channel authorization',
    () async {
      final authenticator = _RecordingAuthenticator()
        ..result = const RiderChannelAuthResult();
      final socket = _FakeRealtimeSocket();
      final realtime = RiderRealtimeService(
        config: _config(),
        authenticator: authenticator,
        opener: (_) => socket,
      );

      await realtime.start(userId: 5);
      final events = <RiderRealtimeEvent>[];
      final subscription = realtime.events.listen(events.add);
      socket.emit(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '123.456'}),
        }),
      );
      await _flush();

      expect(socket.sent, isEmpty);
      expect(realtime.state, RiderRealtimeState.connecting);
      expect(
        events.map((event) => event.name),
        contains('realtime.subscription_error'),
      );

      await subscription.cancel();
      await realtime.stop();
    },
  );

  test(
    'decodes text frames and nested JSON from the subscribed user channel',
    () async {
      final socket = _FakeRealtimeSocket();
      final realtime = RiderRealtimeService(
        config: _config(),
        authenticator: _RecordingAuthenticator(),
        opener: (_) => socket,
      );
      final events = <RiderRealtimeEvent>[];
      final subscription = realtime.events.listen(events.add);
      await realtime.start(userId: 9);

      socket.emit(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '123.456'}),
        }),
      );
      await _flush();
      socket.emit(
        jsonEncode({
          'event': 'delivery.offered',
          'channel': 'private-user.9',
          'data': jsonEncode({'offer_id': 31}),
        }),
      );
      await _flush();
      expect(events, isEmpty);
      socket.emit(
        jsonEncode({
          'event': 'pusher_internal:subscription_succeeded',
          'channel': 'private-user.9',
          'data': '{}',
        }),
      );
      await _flush();
      events.clear();

      socket.emit(
        jsonEncode({
          'event': 'delivery.offered',
          'channel': 'private-user.9',
          'data': jsonEncode({'offer_id': 31, 'delivery_id': 42}),
        }),
      );
      await _flush();

      expect(events, hasLength(1));
      expect(events.single.name, 'delivery.offered');
      expect(events.single.data['delivery_id'], 42);
      expect(events.single.data['offer_id'], 31);

      socket.emit({
        'event': 'delivery.updated',
        'channel': 'private-user.9',
        'data': {'delivery_id': 42},
      });
      await _flush();
      expect(events.last.name, 'delivery.updated');

      socket.emit(
        jsonEncode({
          'event': 'delivery.offered',
          'channel': 'private-user.99',
          'data': jsonEncode({'offer_id': 32}),
        }),
      );
      await _flush();
      expect(events, hasLength(2));

      await subscription.cancel();
      await realtime.stop();
    },
  );

  test(
    'ignores invalid text frames and unknown events without disconnecting',
    () async {
      final socket = _FakeRealtimeSocket();
      final realtime = RiderRealtimeService(
        config: _config(),
        authenticator: _RecordingAuthenticator(),
        opener: (_) => socket,
      );
      final events = <RiderRealtimeEvent>[];
      final subscription = realtime.events.listen(events.add);
      await realtime.start(userId: 9);

      socket.emit('{invalid-json');
      socket.emit(jsonEncode({'event': 'unknown.event', 'data': '{}'}));
      await _flush();

      expect(realtime.state, RiderRealtimeState.connecting);
      expect(events, isEmpty);

      await subscription.cancel();
      await realtime.stop();
    },
  );

  test('reconnects with backoff after the socket drops', () async {
    final authenticator = _RecordingAuthenticator();
    final sockets = <_FakeRealtimeSocket>[];
    final realtime = RiderRealtimeService(
      config: _config(),
      authenticator: authenticator,
      opener: (_) {
        final socket = _FakeRealtimeSocket();
        sockets.add(socket);
        return socket;
      },
      reconnectBaseDelay: const Duration(milliseconds: 20),
      maxReconnectDelay: const Duration(milliseconds: 40),
    );
    final events = <RiderRealtimeEvent>[];
    final subscription = realtime.events.listen(events.add);

    await realtime.start(userId: 3);
    sockets.first.emit(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': 'first.1'}),
      }),
    );
    await _flush();
    sockets.first.emit(
      jsonEncode({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': 'private-user.3',
        'data': '{}',
      }),
    );
    await _flush();
    expect(realtime.state, RiderRealtimeState.connected);

    sockets.first.closeStream();
    final reconnectDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (sockets.length < 2 && DateTime.now().isBefore(reconnectDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(sockets, hasLength(2));
    sockets.last.emit(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': 'second.2'}),
      }),
    );
    await _flush();
    expect(authenticator.calls, 2);
    expect(authenticator.socketId, 'second.2');
    sockets.last.emit(
      jsonEncode({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': 'private-user.3',
        'data': '{}',
      }),
    );
    await _flush();
    expect(realtime.state, RiderRealtimeState.connected);
    expect(
      events.map((event) => event.name),
      contains('realtime.disconnected'),
    );

    await subscription.cancel();
    await realtime.stop();
    for (final socket in sockets) {
      await socket.close();
    }
  });

  test(
    'reconnect while the socket is alive resyncs without reopening',
    () async {
      final socket = _FakeRealtimeSocket();
      var openerCalls = 0;
      final realtime = RiderRealtimeService(
        config: _config(),
        authenticator: _RecordingAuthenticator(),
        opener: (url) {
          openerCalls += 1;
          return socket;
        },
      );
      final events = <RiderRealtimeEvent>[];
      final subscription = realtime.events.listen(events.add);

      await realtime.start(userId: 3);
      socket.emit(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': 'abc.1'}),
        }),
      );
      await _flush();
      socket.emit(
        jsonEncode({
          'event': 'pusher_internal:subscription_succeeded',
          'channel': 'private-user.3',
          'data': '{}',
        }),
      );
      await _flush();

      await realtime.reconnect();
      expect(openerCalls, 1);
      expect(events.map((event) => event.name), contains('realtime.resumed'));

      await subscription.cancel();
      await realtime.stop();
    },
  );

  test('does not open a socket when the app key is missing', () async {
    var openerCalls = 0;
    final realtime = RiderRealtimeService(
      config: RiderRealtimeConfig(
        socketUrl: Uri.parse('ws://localhost:8080'),
        appKey: '  ',
      ),
      authenticator: _RecordingAuthenticator(),
      opener: (_) {
        openerCalls += 1;
        return _FakeRealtimeSocket();
      },
    );

    await realtime.start(userId: 3);
    expect(openerCalls, 0);
    expect(realtime.state, RiderRealtimeState.idle);
  });

  _realtimeControllerChecks();
}

class _EventControllerRepository implements RiderRepository {
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
  Future<List<RiderDelivery>> deliveries() async => const [];

  @override
  Future<RiderDelivery> updateDelivery(int deliveryId, String action) async =>
      delivery;

  @override
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
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
  testWidgets('online rider finds an offer missed by a connected socket', (
    tester,
  ) async {
    final repository = _EventControllerRepository()..offerAvailable = false;
    final controller = RiderAppController(repository);
    final socket = _FakeRealtimeSocket();
    final realtime = RiderRealtimeService(
      config: _config(),
      authenticator: _RecordingAuthenticator(),
      opener: (_) => socket,
    );
    controller.attachRealtime(realtime);

    await controller.login(email: 'rider@example.com', password: 'password');
    await controller.setOnline(true);
    socket.emit(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': 'abc.1'}),
      }),
    );
    await tester.pump();
    socket.emit(
      jsonEncode({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': 'private-user.9',
        'data': '{}',
      }),
    );
    await tester.pump();
    expect(realtime.state, RiderRealtimeState.connected);
    expect(controller.offers, isEmpty);

    repository.offerAvailable = true;
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    expect(controller.offers, hasLength(1));

    controller.dispose();
    realtime.dispose();
    await socket.close();
  });

  test('delivery.offered reloads offers while online', () async {
    final repository = _EventControllerRepository();
    final controller = RiderAppController(repository);
    final socket = _FakeRealtimeSocket();
    final realtime = RiderRealtimeService(
      config: _config(),
      authenticator: _RecordingAuthenticator(),
      opener: (_) => socket,
    );
    controller.attachRealtime(realtime);

    await controller.login(email: 'rider@example.com', password: 'password');
    await controller.setOnline(true);
    await _flush();
    final before = repository.offersCalls;

    socket.emit(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': 'abc.1'}),
      }),
    );
    await _flush();
    socket.emit(
      jsonEncode({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': 'private-user.9',
        'data': '{}',
      }),
    );
    await _flush();

    socket.emit(
      jsonEncode({
        'event': 'delivery.offered',
        'channel': 'private-user.9',
        'data': jsonEncode({'offer_id': 30, 'delivery_id': 8}),
      }),
    );
    await _flush();

    expect(repository.offersCalls, greaterThan(before));
    expect(controller.offers, isNotEmpty);

    controller.dispose();
    realtime.dispose();
    await socket.close();
  });

  test('notification.created refreshes the notification list', () async {
    final repository = _EventControllerRepository();
    final controller = RiderAppController(repository);
    final socket = _FakeRealtimeSocket();
    final realtime = RiderRealtimeService(
      config: _config(),
      authenticator: _RecordingAuthenticator(),
      opener: (_) => socket,
    );
    controller.attachRealtime(realtime);

    await controller.login(email: 'rider@example.com', password: 'password');
    await _flush();
    final before = repository.notificationsCalls;

    socket.emit(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': 'abc.1'}),
      }),
    );
    await _flush();
    socket.emit(
      jsonEncode({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': 'private-user.9',
        'data': '{}',
      }),
    );
    await _flush();

    socket.emit(
      jsonEncode({
        'event': 'notification.created',
        'channel': 'private-user.9',
        'data': jsonEncode({
          'notification': {'id': 11},
        }),
      }),
    );
    await _flush();

    expect(repository.notificationsCalls, greaterThan(before));
    expect(controller.unreadNotificationCount, 1);

    controller.dispose();
    realtime.dispose();
    await socket.close();
  });
}
