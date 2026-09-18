part of '../../app.dart';

typedef CustomerSocketFactory = WebSocketChannel Function(Uri uri);

class CustomerRealtimeConfig {
  CustomerRealtimeConfig({
    required String socketUrl,
    required this.appKey,
    required this.authUri,
  }) : socketBaseUri = Uri.parse(
         socketUrl.endsWith('/') ? socketUrl : '$socketUrl/',
       );

  factory CustomerRealtimeConfig.fromEnvironment(CustomerApiConfig api) =>
      CustomerRealtimeConfig(
        socketUrl: const String.fromEnvironment('TALA_REVERB_WS_URL'),
        appKey: const String.fromEnvironment('TALA_REVERB_APP_KEY'),
        authUri: api.baseUri.resolve('../../broadcasting/auth'),
      );

  final Uri socketBaseUri;
  final String appKey;
  final Uri authUri;

  bool get enabled =>
      (socketBaseUri.scheme == 'ws' || socketBaseUri.scheme == 'wss') &&
      socketBaseUri.hasAuthority &&
      appKey.trim().isNotEmpty;

  Uri get socketUri => socketBaseUri
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

/// Listens on Laravel's private user channel. REST remains the source of truth.
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
  int? _userId;
  String? _token;
  int _generation = 0;
  int _retry = 0;
  bool _foreground = true;
  bool _disposed = false;
  bool _subscribed = false;
  DateTime _lastActivity = DateTime.now();
  final Set<String> _seenOrderEvents = {};
  final Set<int> _seenNotificationIds = {};

  int orderVersion = 0;
  int notificationVersion = 0;
  int? lastOrderId;

  bool get enabled =>
      _config?.enabled == true && _tokenStore != null && _authClient != null;
  bool get isSubscribed => _subscribed;

  Future<void> start(int userId) async {
    stop();
    if (!enabled || _disposed) return;
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
    _token = null;
    _retry = 0;
    _reconnectTimer?.cancel();
    _closeSocket();
    _seenOrderEvents.clear();
    _seenNotificationIds.clear();
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
        await _authorize(socketId, generation, source);
      }
      return;
    }
    if (event == 'pusher:ping') {
      _send('pusher:pong', const {});
      return;
    }
    if (event == 'pusher:error' || event == 'pusher:subscription_error') {
      _disconnected(generation);
      return;
    }
    if (event == 'pusher_internal:subscription_succeeded' ||
        event == 'pusher:subscription_succeeded') {
      if (message['channel'] == _channelName) {
        _subscribed = true;
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
    if (!_subscribed || message['channel'] != _channelName) return;
    final data = _frameData(message['data']);
    if (data == null) return;
    if (event == 'order.updated') {
      final id = _jsonInt(data['id']);
      if (id <= 0) return;
      final signature = '$id:${data['status']}:${data['updated_at']}';
      if (!_remember(_seenOrderEvents, signature)) return;
      lastOrderId = id;
      orderVersion++;
      notifyListeners();
    } else if (event == 'notification.created') {
      final id = _jsonInt(data['id']);
      if (id <= 0 || !_remember(_seenNotificationIds, id)) return;
      notificationVersion++;
      notifyListeners();
    }
  }

  String? get _channelName => _userId == null ? null : 'private-user.$_userId';

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

  Future<void> _authorize(
    String socketId,
    int generation,
    WebSocketChannel source,
  ) async {
    final channel = _channelName;
    final token = _token;
    if (channel == null || token == null) return;
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
      if (response.statusCode == 401 || response.statusCode == 403) {
        stop();
        return;
      }
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
      } else if (idle > const Duration(seconds: 90)) {
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
    _heartbeatTimer?.cancel();
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
