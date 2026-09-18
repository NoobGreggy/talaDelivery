part of '../../app.dart';

/// Lifecycle state of the Reverb/Pusher websocket connection.
enum RiderRealtimeState { idle, connecting, connected }

/// A single authenticated event pushed from the server.
class RiderRealtimeEvent {
  const RiderRealtimeEvent(this.name, [this.data = const <String, dynamic>{}]);

  final String name;
  final Map<String, dynamic> data;

  @override
  String toString() => 'RiderRealtimeEvent($name)';
}

/// Push/Pusher authentication returned by POST /broadcasting/auth.
class RiderChannelAuthResult {
  const RiderChannelAuthResult({
    this.auth,
    this.sharedSecret,
    this.channelData,
  });

  final String? auth;
  final String? sharedSecret;
  final Map<String, dynamic>? channelData;
}

abstract class RiderRealtimeSocket {
  Stream<dynamic> get messages;
  void send(Object data);
  Future<void> close();
}

/// Opens the native web socket (used by the real app and live tests).
typedef RiderRealtimeSocketOpener = RiderRealtimeSocket Function(Uri url);

class NativeRiderRealtimeSocket implements RiderRealtimeSocket {
  NativeRiderRealtimeSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get messages => _channel.stream;

  @override
  void send(Object data) => _channel.sink.add(jsonEncode(data));

  @override
  Future<void> close() => _channel.sink.close();
}

RiderRealtimeSocket _openNativeRealtimeSocket(Uri url) =>
    NativeRiderRealtimeSocket(IOWebSocketChannel.connect(url));

/// Signs private-channel subscription requests against the backend.
abstract class RiderChannelAuthenticator {
  Future<RiderChannelAuthResult> authenticateChannel({
    required String channelName,
    required String socketId,
  });
}

class ApiRiderChannelAuthenticator implements RiderChannelAuthenticator {
  ApiRiderChannelAuthenticator(this._client, this.config, this._tokens);

  final http.Client _client;
  final RiderApiConfig config;
  final RiderTokenStore _tokens;

  @override
  Future<RiderChannelAuthResult> authenticateChannel({
    required String channelName,
    required String socketId,
  }) async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      return const RiderChannelAuthResult();
    }
    // The auth endpoint expects form-encoded socket_id/channel_name (the
    // same shape reverb's own broadcaster posts to Laravel).
    final request = http.Request('POST', config.broadcastAuthUri);
    request.headers.addAll({
      'Accept': 'application/json',
      'X-App-Key': config.apiKey,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/x-www-form-urlencoded',
    });
    request.bodyFields = {'channel_name': channelName, 'socket_id': socketId};
    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(body);
      payload = decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      payload = const {};
    }
    if (response.statusCode != 200) return const RiderChannelAuthResult();
    return RiderChannelAuthResult(
      auth: payload['auth'] is String ? payload['auth'] as String : null,
      sharedSecret: payload['shared_secret'] is String
          ? payload['shared_secret'] as String
          : null,
      channelData: payload['channel_data'] is Map<String, dynamic>
          ? payload['channel_data'] as Map<String, dynamic>
          : null,
    );
  }
}

/// Configuration for connecting to a Reverb websocket endpoint.
class RiderRealtimeConfig {
  const RiderRealtimeConfig({required this.socketUrl, required this.appKey});

  final Uri socketUrl;
  final String appKey;

  bool get isConfigured => appKey.trim().isNotEmpty;

  Uri handshakeUri() => socketUrl.replace(
    path: '/app/${appKey.trim()}',
    queryParameters: {
      'protocol': '7',
      'client': 'flutter-rider',
      'version': '1.0',
      'flash': 'false',
    },
  );
}

/// A minimal Pusher protocol 7 client for the app's private user channel.
///
/// Handles connect, authenticated subscribe, automatic event forwarding and
/// bounded exponential-backoff reconnects. Event payloads never include
/// connection internals (socket ids, signatures) so secrets stay out of logs.
class RiderRealtimeService extends ChangeNotifier {
  RiderRealtimeService({
    required this.config,
    required this.authenticator,
    RiderRealtimeSocketOpener? opener,
    this.reconnectBaseDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(seconds: 30),
  }) : _opener = opener ?? _openNativeRealtimeSocket;

  final RiderRealtimeConfig config;
  final RiderChannelAuthenticator authenticator;
  final RiderRealtimeSocketOpener _opener;
  final Duration reconnectBaseDelay;
  final Duration maxReconnectDelay;

  final StreamController<RiderRealtimeEvent> _events =
      StreamController<RiderRealtimeEvent>.broadcast();

  Stream<RiderRealtimeEvent> get events => _events.stream;

  RiderRealtimeState _state = RiderRealtimeState.idle;
  RiderRealtimeState get state => _state;

  bool _running = false;
  int? _userId;
  RiderRealtimeSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _socketId;

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _events.close();
    super.dispose();
  }

  Future<void> start({required int userId}) async {
    if (_running && _userId == userId) return;
    _userId = userId;
    _running = true;
    if (!config.isConfigured) {
      _state = RiderRealtimeState.idle;
      notifyListeners();
      return;
    }
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    await _connect();
    notifyListeners();
  }

  Future<void> stop() async {
    _running = false;
    _userId = null;
    _reconnectTimer?.cancel();
    await _teardownSocket();
    _setState(RiderRealtimeState.idle);
  }

  Future<void> reconnect() async {
    if (!_running) return;
    if (_socketId != null && _socket != null) {
      // Socket is alive; re-subscribe after a missed wake-up is unnecessary,
      // but the app may have missed events while paused. Ask the listener to
      // resync via a synthetic event.
      _events.add(const RiderRealtimeEvent('realtime.resumed'));
      _setState(RiderRealtimeState.connected);
      return;
    }
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    await _connect();
  }

  Future<void> _connect() async {
    if (!_running) return;
    _setState(RiderRealtimeState.connecting);
    await _teardownSocket();
    try {
      final socket = _opener(config.handshakeUri());
      _socket = socket;
      _subscription = socket.messages.listen(
        (message) => _handleMessage(message),
        onError: (Object error, StackTrace stack) => _scheduleReconnect(),
        onDone: () {
          _socket = null;
          _socketId = null;
          _events.add(const RiderRealtimeEvent('realtime.disconnected'));
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(Object? raw) {
    if (raw is! Map<String, dynamic>) return;
    final event = raw['event'];
    if (event is! String) return;
    final channel = raw['channel'] as String?;
    final data = _decodeData(raw['data']);
    switch (event) {
      case 'pusher:connection_established':
        _socketId = data['socket_id'] is String
            ? data['socket_id'] as String
            : null;
        if (_socketId != null) _subscribeToUserChannel();
        break;
      case 'pusher:subscribe_succeeded':
        _reconnectAttempts = 0;
        _setState(RiderRealtimeState.connected);
        _events.add(
          RiderRealtimeEvent('realtime.connected', {'channel': channel ?? ''}),
        );
        break;
      case 'pusher_internal:subscription_error':
        // V3+ of Reverb replies with an error event when auth is rejected.
        _events.add(RiderRealtimeEvent('realtime.subscription_error', {}));
        break;
      case 'pusher:error':
        _events.add(const RiderRealtimeEvent('realtime.error'));
        break;
      default:
        if (channel != null) _events.add(RiderRealtimeEvent(event, data));
    }
  }

  Map<String, dynamic> _decodeData(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // Fall through to the empty payload.
      }
    }
    return const <String, dynamic>{};
  }

  Future<void> _subscribeToUserChannel() async {
    final userId = _userId;
    final socketId = _socketId;
    final socket = _socket;
    if (userId == null || socketId == null || socket == null) return;
    final channelName = 'private-user.$userId';
    final auth = await authenticator.authenticateChannel(
      channelName: channelName,
      socketId: socketId,
    );
    socket.send({
      'event': 'pusher:subscribe',
      'data': {
        'channel': channelName,
        if (auth.auth != null) 'auth': auth.auth,
      },
    });
  }

  void _scheduleReconnect() {
    if (!_running) return;
    _reconnectTimer?.cancel();
    _setState(RiderRealtimeState.connecting);
    _reconnectAttempts += 1;
    final attempts = _reconnectAttempts;
    final shift = math.min(attempts - 1, 8);
    final exponential = reconnectBaseDelay.inMilliseconds << shift;
    final delay = Duration(
      milliseconds: math.min(exponential, maxReconnectDelay.inMilliseconds),
    );
    _reconnectTimer = Timer(delay, () => _connect());
  }

  Future<void> _teardownSocket() async {
    final subscription = _subscription;
    _subscription = null;
    final socket = _socket;
    _socket = null;
    _socketId = null;
    await subscription?.cancel();
    await socket?.close();
  }

  void _setState(RiderRealtimeState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }
}
