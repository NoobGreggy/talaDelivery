part of '../../app.dart';

enum RiderRealtimeState { idle, connecting, connected }

class RiderRealtimeEvent {
  const RiderRealtimeEvent(this.name, [this.data = const {}]);
  final String name;
  final Map<String, dynamic> data;
}

abstract class RiderRealtimeSocket {
  void on(String event, void Function(dynamic) handler);
  void emitWithAck(String event, Object data, void Function(dynamic) ack);
  void connect();
  void close();
}

typedef RiderRealtimeSocketOpener = RiderRealtimeSocket Function(
  Uri url,
  String token,
);

class NativeRiderRealtimeSocket implements RiderRealtimeSocket {
  NativeRiderRealtimeSocket(Uri url, String token)
    : _socket = io.io(url.toString(), {
        'transports': ['websocket'],
        'autoConnect': false,
        'forceNew': true,
        'reconnection': false,
        'auth': {'token': token},
      });
  final io.Socket _socket;
  @override
  void on(String event, void Function(dynamic) handler) =>
      _socket.on(event, handler);
  @override
  void emitWithAck(String event, Object data, void Function(dynamic) ack) =>
      _socket.emitWithAck(event, data, ack: ack);
  @override
  void connect() => _socket.connect();
  @override
  void close() => _socket.dispose();
}

class RiderRealtimeConfig {
  const RiderRealtimeConfig({required this.socketUrl});
  final Uri socketUrl;
  bool get isConfigured =>
      socketUrl.host.isNotEmpty &&
      const {'http', 'https'}.contains(socketUrl.scheme);
  Uri get namespaceUri => Uri(
    scheme: socketUrl.scheme,
    host: socketUrl.host,
    port: socketUrl.hasPort ? socketUrl.port : null,
    path: '/realtime',
  );
}

/// JWT Socket.IO client. Connected means the server acknowledged our own
/// user room, not merely that a transport was opened.
class RiderRealtimeService extends ChangeNotifier {
  RiderRealtimeService({
    required this.config,
    required this.readToken,
    RiderRealtimeSocketOpener? opener,
    this.reconnectBaseDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.subscriptionTimeout = const Duration(seconds: 10),
  }) : _opener = opener ?? NativeRiderRealtimeSocket.new;

  final RiderRealtimeConfig config;
  final Future<String?> Function() readToken;
  final RiderRealtimeSocketOpener _opener;
  final Duration reconnectBaseDelay, maxReconnectDelay, subscriptionTimeout;
  final _events = StreamController<RiderRealtimeEvent>.broadcast();
  Stream<RiderRealtimeEvent> get events => _events.stream;
  RiderRealtimeState _state = RiderRealtimeState.idle;
  RiderRealtimeState get state => _state;
  RiderRealtimeSocket? _socket;
  Timer? _retry, _deadline;
  bool _running = false, _disposed = false;
  int? _userId;
  int _generation = 0, _attempts = 0;

  Future<void> start({required int userId}) async {
    if (_disposed || (_running && _userId == userId)) return;
    await stop();
    _running = true;
    _userId = userId;
    _attempts = 0;
    await _connect();
  }

  Future<void> stop() async {
    _running = false;
    _userId = null;
    _generation++;
    _retry?.cancel();
    _deadline?.cancel();
    _socket?.close();
    _socket = null;
    _setState(RiderRealtimeState.idle);
  }

  Future<void> reconnect() async {
    if (!_running || _disposed) return;
    _attempts = 0;
    _retry?.cancel();
    await _connect();
  }

  Future<void> _connect() async {
    if (!_running || _disposed || !config.isConfigured) return;
    final generation = ++_generation;
    _deadline?.cancel();
    _socket?.close();
    _socket = null;
    _setState(RiderRealtimeState.connecting);
    bool current() => !_disposed && _running && generation == _generation;
    try {
      final token = await readToken();
      if (!current()) return;
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }
      final socket = _opener(config.namespaceUri, token);
      _socket = socket;
      _deadline = Timer(subscriptionTimeout, () {
        if (current()) _scheduleReconnect();
      });
      socket.on('connect', (_) {
        if (!current()) return;
        socket.emitWithAck('subscribe', {'room': 'user:$_userId'}, (result) {
          if (!current()) return;
          final reply = result is Map && result['data'] is Map
              ? result['data']
              : result;
          if (reply is! Map || reply['success'] != true) {
            _events.add(
              const RiderRealtimeEvent('realtime.subscription_error'),
            );
            _scheduleReconnect();
            return;
          }
          _deadline?.cancel();
          _attempts = 0;
          _setState(RiderRealtimeState.connected);
          _events.add(const RiderRealtimeEvent('realtime.connected'));
        });
      });
      for (final event in ['disconnect', 'connect_error', 'error']) {
        socket.on(event, (_) {
          if (!current()) return;
          _events.add(const RiderRealtimeEvent('realtime.disconnected'));
          _scheduleReconnect();
        });
      }
      for (final event in [
        'delivery.offered',
        'delivery.updated',
        'offer.updated',
        'notification.created',
      ]) {
        socket.on(event, (raw) {
          if (!current() ||
              state != RiderRealtimeState.connected ||
              raw is! Map) {
            return;
          }
          _events.add(
            RiderRealtimeEvent(event, Map<String, dynamic>.from(raw)),
          );
        });
      }
      socket.connect();
    } catch (_) {
      if (current()) _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_running || _disposed) return;
    _generation++;
    _deadline?.cancel();
    _socket?.close();
    _socket = null;
    _setState(RiderRealtimeState.connecting);
    _retry?.cancel();
    final delay = math.min(
      reconnectBaseDelay.inMilliseconds << math.min(_attempts++, 8),
      maxReconnectDelay.inMilliseconds,
    );
    _retry = Timer(Duration(milliseconds: delay), () => unawaited(_connect()));
  }

  void _setState(RiderRealtimeState value) {
    if (_disposed || value == _state) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    unawaited(_events.close());
    super.dispose();
  }
}
