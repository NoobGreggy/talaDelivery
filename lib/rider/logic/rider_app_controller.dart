part of '../app.dart';

class RiderAppController extends ChangeNotifier {
  RiderAppController(this._repository);

  final RiderRepository _repository;
  RiderUser? user;
  RiderProfile? profile;
  List<RiderOffer> offers = const [];
  List<RiderDelivery> deliveries = const [];
  RiderEarningsSummary? earningsSummary;
  List<RiderNotification> notifications = const [];
  List<RiderStore> nearbyStores = const [];
  RiderDelivery? activeDelivery;
  DateTime? onlineSince;
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;
  Map<String, String> fieldErrors = const {};

  static const _offerFallbackPollInterval = Duration(seconds: 15);

  /// Slow safety reconciliation used while the private realtime channel is
  /// healthy; the fast fallback poll only applies while it is disconnected.
  static const _offerConnectedPollInterval = Duration(seconds: 90);

  RiderRealtimeService? _realtime;
  StreamSubscription<RiderRealtimeEvent>? _realtimeSubscription;
  RiderLocationService? _location;
  bool _locationNoticeShown = false;
  Timer? _offerPollTimer;
  bool _reconcilingOffers = false;
  bool _resyncing = false;
  bool _loadingDeliveries = false;
  RiderRealtimeState _lastRealtimeState = RiderRealtimeState.idle;

  bool _disposed = false;
  bool _foreground = true;

  RiderRealtimeService? get realtime => _realtime;

  /// Offer poll interval chosen from socket health: fast (15s) only while the
  /// private channel is disconnected, slow safety reconciliation (90s) while
  /// it is healthy.
  Duration get offerPollInterval =>
      _realtime?.state == RiderRealtimeState.connected
      ? _offerConnectedPollInterval
      : _offerFallbackPollInterval;

  List<RiderDelivery> get completedDeliveries => deliveries
      .where((delivery) => delivery.isDelivered)
      .toList(growable: false);

  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;

  ValueListenable<RiderLatLng?>? get riderPosition => _location?.position;

  double get todayEarnings => earningsSummary?.today.earnings ?? 0;

  int get todayDeliveries => earningsSummary?.today.completedDeliveries ?? 0;

  void attachRealtime(RiderRealtimeService? service) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtime?.removeListener(_onRealtimeStateChanged);
    _realtime = service;
    if (service != null) {
      service.addListener(_onRealtimeStateChanged);
      _lastRealtimeState = service.state;
      _realtimeSubscription = service.events.listen(_handleRealtimeEvent);
    } else {
      _lastRealtimeState = RiderRealtimeState.idle;
    }
  }

  void _onRealtimeStateChanged() {
    final state = _realtime?.state ?? RiderRealtimeState.idle;
    if (state == _lastRealtimeState) return;
    _lastRealtimeState = state;
    _riderPerfEvent('rider.realtime.state $state');
    // The offer reconciliation cadence adapts to socket health.
    if (user != null && (profile?.isOnline ?? false)) _startOfferPoll();
  }

  void attachLocation(RiderLocationService? service) {
    _location = service;
  }

  /// Called when the app returns to the foreground: resync state and restore
  /// socket/location wiring without showing a spinner.
  Future<void> handleAppResumed() async {
    _foreground = true;
    _location?.setForeground(true);
    if (_disposed || user == null) return;
    final startedAt = DateTime.now();
    await _realtime?.reconnect();
    await _resync();
    if (profile?.isOnline ?? false) {
      _startShift();
    } else {
      _stopShift();
      if (activeDelivery != null) _startLocation();
    }
    _riderPerfTrace('rider.resume', startedAt);
  }

  /// Keep the active delivery foreground location service alive when opening
  /// Maps or locking the screen. Availability-only GPS stops outside the app.
  void handleAppPaused() {
    _foreground = false;
    _location?.setForeground(false);
    if (_disposed || user == null) return;
    _stopOfferPoll();
    if (activeDelivery == null) _location?.stop();
  }

  Future<bool> restore() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.restoreSession();
      if (user == null) return false;
      await _loadData();
      if (profile?.isOnline ?? false) {
        onlineSince ??= DateTime.now();
        _startShift();
      } else {
        onlineSince = null;
        _startRealtime();
      }
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    isSubmitting = true;
    errorMessage = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      user = await _repository.login(email: email, password: password);
      await _loadData();
      if (profile?.isOnline ?? false) {
        onlineSince ??= DateTime.now();
        _startShift();
      } else {
        onlineSince = null;
        _startRealtime();
      }
      return true;
    } on RiderApiException catch (error) {
      errorMessage = error.message;
      fieldErrors = error.fieldErrors;
      return false;
    } catch (error) {
      errorMessage = _messageFor(error);
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _loadData();
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setOnline(bool value) async {
    final succeeded = await _runMutation(() async {
      profile = await _repository.setOnline(value);
      offers = value ? await _repository.offers() : const [];
    });
    if (succeeded) {
      if (value) {
        onlineSince ??= DateTime.now();
        _startShift();
      } else {
        onlineSince = null;
        _stopShift();
      }
    }
    return succeeded;
  }

  Future<void> reconcileOffers() async {
    if (!(profile?.isOnline ?? false)) {
      offers = const [];
      notifyListeners();
      return;
    }
    if (_reconcilingOffers) return;
    _reconcilingOffers = true;
    final startedAt = DateTime.now();
    String? error;
    try {
      offers = await _repository.offers();
    } catch (errorObject) {
      error = _messageFor(errorObject);
    } finally {
      _reconcilingOffers = false;
      _riderPerfTrace('rider.reconcileOffers', startedAt);
    }
    if (error != null) errorMessage = error;
    notifyListeners();
  }

  Future<RiderDelivery?> accept(RiderOffer offer) async {
    final succeeded = await _runMutation(() async {
      final accepted = await _repository.acceptOffer(offer.id);
      activeDelivery = accepted.delivery;
      offers = offers.where((item) => item.id != offer.id).toList();
      await _reloadProfileAndDeliveries();
    });
    return succeeded ? activeDelivery : null;
  }

  Future<bool> reject(RiderOffer offer) => _runMutation(() async {
    await _repository.rejectOffer(offer.id);
    offers = offers.where((item) => item.id != offer.id).toList();
  });

  Future<void> markNotificationRead(int notificationId) async {
    try {
      await _repository.markNotificationRead(notificationId);
      notifications = notifications
          .map((notification) {
            if (notification.id != notificationId) return notification;
            return RiderNotification(
              id: notification.id,
              type: notification.type,
              title: notification.title,
              message: notification.message,
              isRead: true,
              createdAt: notification.createdAt,
              readAt: DateTime.now(),
              data: notification.data,
            );
          })
          .toList(growable: false);
      notifyListeners();
    } catch (_) {
      // Marking read is best-effort; the list still reflects the server state.
    }
  }

  Future<RiderDelivery?> advanceDelivery(String action) async {
    final delivery = activeDelivery;
    if (delivery == null) return null;
    RiderDelivery? updated;
    final succeeded = await _runMutation(() async {
      updated = await _repository.updateDelivery(delivery.id, action);
      activeDelivery = updated!.isActive ? updated : null;
      await _reloadProfileAndDeliveries();
    });
    return succeeded ? updated : null;
  }

  Future<void> logout() async {
    _stopShift();
    await _realtime?.stop();
    try {
      await _repository.logout();
    } finally {
      user = null;
      profile = null;
      offers = const [];
      deliveries = const [];
      earningsSummary = null;
      notifications = const [];
      nearbyStores = const [];
      activeDelivery = null;
      onlineSince = null;
      errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopShift();
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    super.dispose();
  }

  Future<void> _loadData() async {
    profile = await _repository.profile();
    await _reloadDeliveries();
    offers = profile!.isOnline ? await _repository.offers() : const [];
    await _reloadNearbyStores();
    await _reloadNotifications();
  }

  Future<void> _resync() async {
    if (_disposed || _resyncing) return;
    _resyncing = true;
    final startedAt = DateTime.now();
    try {
      profile = await _repository.profile();
      await _reloadDeliveries();
      await _reloadNotifications();
      offers = profile!.isOnline ? await _repository.offers() : const [];
      await _reloadNearbyStores();
      notifyListeners();
    } catch (_) {
      // Foreground resync is best-effort; the user can pull-to-refresh.
    } finally {
      _resyncing = false;
      _riderPerfTrace('rider.resync', startedAt);
    }
  }

  /// Targeted refresh for a single `delivery.updated` event. Fetches only the
  /// resources the event can affect (profile, deliveries, earnings) instead of
  /// a full resync that also reloads notifications and offers.
  Future<void> _targetedDeliveryRefresh() async {
    if (_disposed || _resyncing) return;
    _resyncing = true;
    final startedAt = DateTime.now();
    try {
      await _reloadProfileAndDeliveries();
      notifyListeners();
    } catch (_) {
      // Best-effort; realtime remains the source of truth on the next event.
    } finally {
      _resyncing = false;
      _riderPerfTrace('rider.delivery.refresh', startedAt);
    }
  }

  Future<void> _reloadProfileAndDeliveries() async {
    profile = await _repository.profile();
    await _reloadDeliveries();
  }

  Future<void> _reloadDeliveries() async {
    if (_loadingDeliveries) return;
    _loadingDeliveries = true;
    try {
      final results = await Future.wait<Object>([
        _repository.deliveries(),
        _repository.earningsSummary(),
      ]);
      deliveries = results[0] as List<RiderDelivery>;
      earningsSummary = results[1] as RiderEarningsSummary;
      // The deliveries endpoint includes order items and the store relation,
      // while the compact profile relation may not. Prefer the fully loaded
      // record so restored deliveries retain their checklist and contacts.
      activeDelivery = deliveries.where((item) => item.isActive).firstOrNull;
      activeDelivery ??= profile?.currentDelivery;
      _location?.setActiveDelivery(activeDelivery?.id);
      if (activeDelivery != null && _foreground) _location?.start();
      if (activeDelivery == null &&
          (!_foreground || !(profile?.isOnline ?? false))) {
        _location?.stop();
      }
    } finally {
      _loadingDeliveries = false;
    }
  }

  Future<void> _reloadNotifications() async {
    try {
      notifications = await _repository.notifications();
    } catch (_) {
      // Notifications are secondary; don't block the main data load on them.
    }
  }

  Future<void> _reloadNearbyStores() async {
    final repository = _repository;
    if (repository is! ApiRiderRepository) {
      nearbyStores = const [];
      return;
    }
    try {
      nearbyStores = await repository.nearbyStores();
    } catch (_) {
      // Nearby-store pins are secondary to the shift and offer workflow.
    }
  }

  Future<bool> _runMutation(Future<void> Function() operation) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void _notifyControllerListeners() => notifyListeners();

  String _messageFor(Object error) => switch (error) {
    RiderApiException exception => exception.message,
    FormatException _ => 'The server returned unexpected rider data.',
    _ => 'Unable to reach TalaDelivery. Please try again.',
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
