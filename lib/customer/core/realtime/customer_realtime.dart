part of '../../app.dart';

typedef CustomerSocketFactory = WebSocketChannel Function(Uri uri);

class CustomerRealtimeConfig {
  CustomerRealtimeConfig({
    required String socketUrl,
    required this.appKey,
    required this.authUri,
    this.socketIo = false,
  }) : socketBaseUri = Uri.parse(
         socketUrl.endsWith('/') ? socketUrl : '$socketUrl/',
       );

  factory CustomerRealtimeConfig.fromEnvironment(CustomerApiConfig api) =>
      CustomerRealtimeConfig(
        socketUrl: const String.fromEnvironment(
          'TALA_SOCKET_IO_URL',
          defaultValue: 'https://realtime.tala-works.online',
        ),
        appKey: '',
        authUri: api.baseUri,
        socketIo: true,
      );

  final Uri socketBaseUri;
  final String appKey;
  final Uri authUri;
  final bool socketIo;

  bool get enabled => socketIo
      ? socketBaseUri.hasAuthority
      : (socketBaseUri.scheme == 'ws' || socketBaseUri.scheme == 'wss') &&
            socketBaseUri.hasAuthority &&
            appKey.trim().isNotEmpty;

  Uri get socketUri => socketIo
      ? socketBaseUri.replace(
          scheme: ['https', 'wss'].contains(socketBaseUri.scheme)
              ? 'wss'
              : 'ws',
          path: '/socket.io/',
          queryParameters: {'EIO': '4', 'transport': 'websocket'},
        )
      : socketBaseUri
            .resolve('app/${Uri.encodeComponent(appKey)}')
            .replace(
              queryParameters: {
                'protocol': '7',
                'client': 'tala-flutter',
                'version': '1.0',
                'flash': 'false',
              },
            );
}

/// Authenticated user/delivery tracking. REST remains the source of truth.
class CustomerRealtimeController extends ChangeNotifier {
  factory CustomerRealtimeController({
    CustomerRealtimeConfig? config,
    CustomerTokenStore? tokenStore,
    http.Client? authClient,
    CustomerSocketFactory? socketFactory,
  }) => CustomerRealtimeController._(
    config,
    tokenStore,
    authClient,
    socketFactory ?? WebSocketChannel.connect,
  );

  CustomerRealtimeController._(
    this._config,
    this._tokenStore,
    this._authClient,
    this._socketFactory,
  );

  final CustomerRealtimeConfig? _config;
  final CustomerTokenStore? _tokenStore;
  final http.Client? _authClient;
  final CustomerSocketFactory _socketFactory;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _subscriptionDeadline;
  int? _userId;
  String? _token;
  int _generation = 0;
  int _retry = 0;
  bool _foreground = true;
  bool _disposed = false;
  bool _subscribed = false;
  String? _socketId;
  int _ackId = 0;
  final Map<int, String> _pendingRooms = {};
  int? _deliveryId;
  DateTime _lastActivity = DateTime.now();
  final Set<String> _seenOrderEvents = {};
  final Set<int> _seenNotificationIds = {};
  final Set<String> _subscribedChannels = {};

  int orderVersion = 0;
  int notificationVersion = 0;
  int locationVersion = 0;
  int? lastOrderId;
  CustomerRiderLocation? lastRiderLocation;

  bool get enabled =>
      _config?.enabled == true && _tokenStore != null && _authClient != null;
  bool get isSubscribed => _subscribed;
  bool get isDeliverySubscribed =>
      _deliveryChannelName != null &&
      _subscribedChannels.contains(_deliveryChannelName);

  void watchDelivery(int? deliveryId) {
    if (_deliveryId == deliveryId) return;
    final previous = _deliveryChannelName;
    _deliveryId = deliveryId;
    lastRiderLocation = null;
    locationVersion++;
    if (previous != null && _socket != null) {
      if (_config?.socketIo == true) {
        _socketIoEvent('unsubscribe', {'room': previous});
      } else {
        _send('pusher:unsubscribe', {'channel': previous});
      }
      _subscribedChannels.remove(previous);
    }
    final socketId = _socketId;
    final socket = _socket;
    if (_config?.socketIo == true) {
      if (deliveryId != null && _subscribed) {
        _subscribeRoom(_deliveryChannelName!);
      }
      notifyListeners();
      return;
    }
    if (deliveryId != null && socketId != null && socket != null) {
      unawaited(
        _authorizeChannel(_deliveryChannelName!, socketId, _generation, socket),
      );
    }
    notifyListeners();
  }

  Future<void> start(int userId) async {
    stop();
    if (_disposed) return;
    if (!enabled) {
      debugPrint(
        'Customer realtime: missing or invalid WebSocket configuration.',
      );
      return;
    }
    _userId = userId;
    final generation = _generation;
    try {
      final token = await _tokenStore!.read();
      if (!_current(generation) || token == null || token.isEmpty) return;
      _token = token;
      if (_foreground) await _open(generation);
    } catch (_) {
      _scheduleReconnect(generation);
    }
  }

  void pause() {
    _foreground = false;
    _reconnectTimer?.cancel();
    _closeSocket();
  }

  void resume() {
    if (_disposed) return;
    _foreground = true;
    if (_userId != null && _token != null && enabled && _socket == null) {
      unawaited(_open(_generation));
    }
  }

  void stop() {
    _generation++;
    _userId = null;
    _deliveryId = null;
    _token = null;
    _retry = 0;
    _reconnectTimer?.cancel();
    _closeSocket();
    _seenOrderEvents.clear();
    _seenNotificationIds.clear();
    lastRiderLocation = null;
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && _userId != null;

  Future<void> _open(int generation) async {
    if (!_current(generation) ||
        !_foreground ||
        _token == null ||
        _socket != null) {
      return;
    }
    WebSocketChannel? socket;
    try {
      socket = _socketFactory(_config!.socketUri);
      _socket = socket;
      _lastActivity = DateTime.now();
      _subscription = socket.stream.listen(
        (frame) => unawaited(_onFrame(frame, generation, socket!)),
        onError: (_) => _disconnected(generation),
        onDone: () => _disconnected(generation),
      );
      _subscriptionDeadline = Timer(const Duration(seconds: 15), () {
        if (_socket == socket && !_subscribed) {
          debugPrint(
            'Customer realtime: private channel subscription timed out; reconnecting.',
          );
          _disconnected(generation);
        }
      });
      await socket.ready.timeout(const Duration(seconds: 8));
      if ((!_current(generation) || !_foreground) && _socket == socket) {
        _closeSocket();
      }
    } catch (_) {
      if (_socket == socket) _closeSocket();
      _scheduleReconnect(generation);
    }
  }

  Future<void> _onFrame(
    Object? frame,
    int generation,
    WebSocketChannel source,
  ) async {
    if (!_current(generation) ||
        !_foreground ||
        _socket != source ||
        frame is! String) {
      return;
    }
    _lastActivity = DateTime.now();
    if (_config?.socketIo == true) {
      _onSocketIoFrame(frame, generation);
      return;
    }
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(frame);
      if (decoded is! Map<String, dynamic>) return;
      message = decoded;
    } on FormatException {
      return;
    }

    final event = message['event'];
    if (event == 'pusher:connection_established') {
      final data = _frameData(message['data']);
      final socketId = data?['socket_id'];
      if (socketId is String && socketId.isNotEmpty) {
        _socketId = socketId;
        await _authorizeChannel(_channelName!, socketId, generation, source);
        final deliveryChannel = _deliveryChannelName;
        if (deliveryChannel != null && _current(generation)) {
          await _authorizeChannel(
            deliveryChannel,
            socketId,
            generation,
            source,
          );
        }
      }
      return;
    }
    if (event == 'pusher:ping') {
      _send('pusher:pong', const {});
      return;
    }
    if (event == 'pusher:error' || event == 'pusher:subscription_error') {
      debugPrint(
        'Customer realtime: server rejected the connection or subscription.',
      );
      _disconnected(generation);
      return;
    }
    if (event == 'pusher_internal:subscription_succeeded' ||
        event == 'pusher:subscription_succeeded') {
      final channel = message['channel'];
      if (channel is String) _subscribedChannels.add(channel);
      if (channel == _channelName) {
        _subscriptionDeadline?.cancel();
        _subscribed = true;
        debugPrint('Customer realtime: private user channel subscribed.');
        _customerPerfEvent('customer.realtime.connected');
        _retry = 0;
        _startHeartbeat(generation);
        // Events can be missed during a disconnected interval.
        lastOrderId = null;
        orderVersion++;
        notificationVersion++;
        notifyListeners();
      }
      return;
    }
    final data = _frameData(message['data']);
    if (data == null) return;
    if (event == 'rider.location.updated' &&
        message['channel'] == _deliveryChannelName &&
        _subscribedChannels.contains(_deliveryChannelName)) {
      final location = CustomerRiderLocation.fromJson(data);
      if (location.deliveryId != _deliveryId || !location.hasCoordinates) {
        return;
      }
      final current = lastRiderLocation;
      if (current != null &&
          ((location.sequence > 0 && location.sequence <= current.sequence) ||
              (location.sequence == 0 &&
                  location.recordedAt != null &&
                  current.recordedAt != null &&
                  !location.recordedAt!.isAfter(current.recordedAt!)))) {
        return;
      }
      lastRiderLocation = location;
      locationVersion++;
      _customerPerfEvent('customer.realtime.location.updated');
      notifyListeners();
      return;
    }
    if (!_subscribed || message['channel'] != _channelName) return;
    if (event == 'order.updated' || event == 'delivery.updated') {
      final id = _jsonInt(
        event == 'delivery.updated' ? data['order_id'] : data['id'],
      );
      if (id <= 0) return;
      final signature =
          '$event:$id:${data['id']}:${data['status']}:${data['updated_at']}';
      if (!_remember(_seenOrderEvents, signature)) return;
      lastOrderId = id;
      orderVersion++;
      _customerPerfEvent('customer.realtime.dispatch $event');
      notifyListeners();
    } else if (event == 'notification.created') {
      final id = _jsonInt(data['id']);
      if (id <= 0 || !_remember(_seenNotificationIds, id)) return;
      notificationVersion++;
      _customerPerfEvent('customer.realtime.dispatch $event');
      notifyListeners();
    }
  }

  String? get _channelName => _userId == null
      ? null
      : (_config?.socketIo == true ? 'user:$_userId' : 'private-user.$_userId');
  String? get _deliveryChannelName => _deliveryId == null
      ? null
      : (_config?.socketIo == true
            ? 'delivery:$_deliveryId'
            : 'private-delivery.$_deliveryId');

  void _socketIoEvent(String event, Map<String, dynamic> data) =>
      _socket?.sink.add('42/realtime,${jsonEncode([event, data])}');

  void _subscribeRoom(String room) {
    final id = ++_ackId;
    _pendingRooms[id] = room;
    _socket?.sink.add(
      '42/realtime,$id${jsonEncode([
        'subscribe',
        {'room': room},
      ])}',
    );
  }

  void _onSocketIoFrame(String frame, int generation) {
    if (frame.startsWith('0')) {
      _socket?.sink.add('40/realtime,${jsonEncode({'token': _token})}');
      return;
    }
    if (frame.startsWith('2')) {
      _socket?.sink.add('3${frame.substring(1)}');
      return;
    }
    if (frame.startsWith('40/realtime,')) {
      _subscribeRoom(_channelName!);
      return;
    }
    if (frame.startsWith('44/realtime,') || frame.startsWith('41/realtime')) {
      _disconnected(generation);
      return;
    }
    try {
      final ack = RegExp(r'^43/realtime,(\d+)(.*)$').firstMatch(frame);
      if (ack != null) {
        final room = _pendingRooms.remove(int.parse(ack.group(1)!));
        final replies = jsonDecode(ack.group(2)!) as List<dynamic>;
        final envelope = replies.first as Map<String, dynamic>;
        final result = envelope['data'] is Map<String, dynamic>
            ? envelope['data'] as Map<String, dynamic>
            : envelope;
        if (result['success'] != true) {
          _disconnected(generation);
          return;
        }
        if (room != null) _subscribedChannels.add(room);
        if (room == _channelName) {
          _subscribed = true;
          _subscriptionDeadline?.cancel();
          _retry = 0;
          lastOrderId = null;
          orderVersion++;
          notificationVersion++;
          _startHeartbeat(generation);
          if (_deliveryChannelName != null) {
            _subscribeRoom(_deliveryChannelName!);
          }
          notifyListeners();
        }
        return;
      }
      if (!frame.startsWith('42/realtime,') || !_subscribed) return;
      final values =
          jsonDecode(frame.substring('42/realtime,'.length)) as List<dynamic>;
      final event = values[0];
      final data = values[1] as Map<String, dynamic>;
      if (event == 'order.updated') {
        final id = _jsonInt(data['orderId']);
        if (id <= 0 ||
            !_remember(
              _seenOrderEvents,
              '$id:${data['status']}:${data['updatedAt']}',
            )) {
          return;
        }
        lastOrderId = id;
        orderVersion++;
        notifyListeners();
      } else if (event == 'notification.created') {
        if (!_remember(_seenNotificationIds, _jsonInt(data['id']))) return;
        notificationVersion++;
        notifyListeners();
      } else if (event == 'rider.location' &&
          isDeliverySubscribed &&
          _jsonInt(data['deliveryId']) == _deliveryId) {
        final next = CustomerRiderLocation.fromJson(data);
        final previous = lastRiderLocation;
        if (!next.hasCoordinates ||
            next.recordedAt == null ||
            (previous?.recordedAt != null &&
                !next.recordedAt!.isAfter(previous!.recordedAt!))) {
          return;
        }
        lastRiderLocation = next;
        locationVersion++;
        notifyListeners();
      }
    } catch (_) {
      /* Ignore malformed transport frames. REST stays authoritative. */
    }
  }

  Map<String, dynamic>? _frameData(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  bool _remember<T>(Set<T> seen, T value) {
    if (!seen.add(value)) return false;
    if (seen.length > 100) seen.remove(seen.first);
    return true;
  }

  Future<void> _authorizeChannel(
    String channel,
    String socketId,
    int generation,
    WebSocketChannel source,
  ) async {
    final token = _token;
    if (token == null) return;
    try {
      final response = await _authClient!
          .post(
            _config!.authUri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: {'socket_id': socketId, 'channel_name': channel},
          )
          .timeout(const Duration(seconds: 8));
      if (!_current(generation) || !_foreground || _socket != source) return;
      if (response.statusCode != 200) {
        debugPrint(
          'Customer realtime: channel authorization failed (HTTP ${response.statusCode}).',
        );
      }
      if (response.statusCode == 401 ||
          (response.statusCode == 403 && channel == _channelName)) {
        stop();
        return;
      }
      if (response.statusCode == 403) return;
      if (response.statusCode != 200) {
        _disconnected(generation);
        return;
      }
      final result = jsonDecode(response.body);
      final auth = result is Map<String, dynamic> ? result['auth'] : null;
      if (auth is! String || auth.isEmpty) {
        _disconnected(generation);
        return;
      }
      _send('pusher:subscribe', {'channel': channel, 'auth': auth});
    } catch (_) {
      _disconnected(generation);
    }
  }

  void _send(String event, Map<String, dynamic> data) =>
      _socket?.sink.add(jsonEncode({'event': event, 'data': data}));

  void _startHeartbeat(int generation) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_current(generation) || !_foreground || _socket == null) return;
      final idle = DateTime.now().difference(_lastActivity);
      if (idle > const Duration(seconds: 150)) {
        _disconnected(generation);
      } else if (idle > const Duration(seconds: 90) &&
          _config?.socketIo != true) {
        _send('pusher:ping', const {});
      }
    });
  }

  void _disconnected(int generation) {
    if (!_current(generation)) return;
    _closeSocket();
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (!_current(generation) ||
        !_foreground ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    final delay = Duration(seconds: (1 << _retry.clamp(0, 5)).clamp(1, 30));
    _retry++;
    _reconnectTimer = Timer(delay, () => unawaited(_open(generation)));
  }

  void _closeSocket() {
    _subscribed = false;
    _socketId = null;
    _subscribedChannels.clear();
    _pendingRooms.clear();
    _heartbeatTimer?.cancel();
    _subscriptionDeadline?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _socket?.sink.close();
    _socket = null;
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }
}
