import 'dart:async';

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
  RiderChannelAuthResult result = const RiderChannelAuthResult(
    auth: 'signed-token',
  );

  @override
  Future<RiderChannelAuthResult> authenticateChannel({
    required String channelName,
    required String socketId,
  }) async {
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

      socket.emit({
        'event': 'pusher:connection_established',
        'data': {'socket_id': '123.456'},
      });
      await _flush();

      expect(authenticator.channelName, 'private-user.5');
      expect(authenticator.socketId, '123.456');
      final subscribeMessage = socket.sent.last as Map<String, dynamic>;
      expect(subscribeMessage['event'], 'pusher:subscribe');
      final subscribeData = subscribeMessage['data'] as Map<String, dynamic>;
      expect(subscribeData['channel'], 'private-user.5');
      expect(subscribeData['auth'], 'signed-token');

      socket.emit({
        'event': 'pusher:subscribe_succeeded',
        'channel': 'private-user.5',
      });
      await _flush();
      expect(realtime.state, RiderRealtimeState.connected);

      await realtime.stop();
      expect(realtime.state, RiderRealtimeState.idle);
      expect(socket.closes, greaterThanOrEqualTo(1));
    },
  );

  test(
    'subscribes without auth when the backend rejects the channel',
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
      socket.emit({
        'event': 'pusher:connection_established',
        'data': {'socket_id': '123.456'},
      });
      await _flush();

      final subscribeData =
          (socket.sent.last as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      expect(subscribeData.containsKey('auth'), isFalse);

      final events = <RiderRealtimeEvent>[];
      final subscription = realtime.events.listen(events.add);
      socket.emit({
        'event': 'pusher_internal:subscription_error',
        'data': {'status': 403},
      });
      await _flush();

      expect(
        events.map((event) => event.name),
        contains('realtime.subscription_error'),
      );

      await subscription.cancel();
      await realtime.stop();
    },
  );

  test(
    'forwards app events from the user channel with their payload',
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

      socket.emit({
        'event': 'delivery.offered',
        'channel': 'private-user.9',
        'data': {'delivery_id': 42},
      });
      await _flush();

      expect(events, hasLength(1));
      expect(events.single.name, 'delivery.offered');
      expect(events.single.data['delivery_id'], 42);

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
    sockets.first.closeStream();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(sockets, hasLength(2));
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
      socket.emit({
        'event': 'pusher:connection_established',
        'data': {'socket_id': 'abc.1'},
      });
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
    return _profile.isOnline
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

    socket.emit({
      'event': 'delivery.offered',
      'channel': 'private-user.9',
      'data': {'delivery_id': 8},
    });
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

    socket.emit({
      'event': 'notification.created',
      'channel': 'private-user.9',
      'data': {
        'notification': {'id': 11},
      },
    });
    await _flush();

    expect(repository.notificationsCalls, greaterThan(before));
    expect(controller.unreadNotificationCount, 1);

    controller.dispose();
    realtime.dispose();
    await socket.close();
  });
}
