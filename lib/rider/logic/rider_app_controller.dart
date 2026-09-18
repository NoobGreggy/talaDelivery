part of '../app.dart';

class RiderAppController extends ChangeNotifier {
  RiderAppController(this._repository);

  final RiderRepository _repository;
  RiderUser? user;
  RiderProfile? profile;
  List<RiderOffer> offers = const [];
  List<RiderDelivery> deliveries = const [];
  List<RiderNotification> notifications = const [];
  RiderDelivery? activeDelivery;
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;
  Map<String, String> fieldErrors = const {};

  static const _offerFallbackPollInterval = Duration(seconds: 15);

  RiderRealtimeService? _realtime;
  StreamSubscription<RiderRealtimeEvent>? _realtimeSubscription;
  RiderLocationService? _location;
  bool _locationNoticeShown = false;
  Timer? _offerPollTimer;

  bool _disposed = false;

  RiderRealtimeService? get realtime => _realtime;

  List<RiderDelivery> get completedDeliveries => deliveries
      .where((delivery) => delivery.isDelivered)
      .toList(growable: false);

  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;

  void attachRealtime(RiderRealtimeService? service) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtime = service;
    if (service != null) {
      _realtimeSubscription = service.events.listen(_handleRealtimeEvent);
    }
  }

  void attachLocation(RiderLocationService? service) {
    _location = service;
  }

  /// Called when the app returns to the foreground: resync state and restore
  /// socket/location wiring without showing a spinner.
  Future<void> handleAppResumed() async {
    if (_disposed || user == null) return;
    await _realtime?.reconnect();
    await _resync();
    if (profile?.isOnline ?? false) {
      _startShift();
    } else {
      _stopShift();
    }
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
        _startShift();
      } else {
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
      _startShift();
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
        _startShift();
      } else {
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
    try {
      offers = await _repository.offers();
    } catch (error) {
      errorMessage = _messageFor(error);
    }
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
      notifications = const [];
      activeDelivery = null;
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
    await _reloadNotifications();
  }

  Future<void> _resync() async {
    if (_disposed) return;
    try {
      profile = await _repository.profile();
      await _reloadDeliveries();
      await _reloadNotifications();
      offers = profile!.isOnline ? await _repository.offers() : const [];
      notifyListeners();
    } catch (_) {
      // Foreground resync is best-effort; the user can pull-to-refresh.
    }
  }

  Future<void> _reloadProfileAndDeliveries() async {
    profile = await _repository.profile();
    await _reloadDeliveries();
  }

  Future<void> _reloadDeliveries() async {
    deliveries = await _repository.deliveries();
    activeDelivery = profile?.currentDelivery;
    activeDelivery ??= deliveries.where((item) => item.isActive).firstOrNull;
  }

  Future<void> _reloadNotifications() async {
    try {
      notifications = await _repository.notifications();
    } catch (_) {
      // Notifications are secondary; don't block the main data load on them.
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

  // MARK: - Realtime

  void _startRealtime() {
    final realtime = _realtime;
    final userId = user?.id;
    if (realtime == null || userId == null) return;
    unawaited(realtime.start(userId: userId));
  }

  Future<void> _handleRealtimeEvent(RiderRealtimeEvent event) async {
    if (_disposed) return;
    switch (event.name) {
      case 'delivery.offered':
        if (profile?.isOnline ?? false) await reconcileOffers();
      case 'delivery.updated':
        if ((profile?.isOnline ?? false) || activeDelivery != null) {
          await _resync();
        }
      case 'notification.created':
        await _reloadNotifications();
        notifyListeners();
      case 'realtime.connected':
        if (user != null) await _resync();
      case 'realtime.resumed':
        if (user != null) await _resync();
    }
  }

  // MARK: - Shift lifecycle (location reporting + offer poll)

  void _startShift() {
    _startRealtime();
    _startLocation();
    _startOfferPoll();
  }

  void _stopShift() {
    _stopOfferPoll();
    _location?.stop();
    _locationNoticeShown = false;
  }

  void _startLocation() {
    final location = _location;
    if (location == null) return;
    location.start();
    unawaited(_handleLocationReport(location.reportOnce()));
  }

  Future<void> _handleLocationReport(Future<RiderLocationReport> report) async {
    final outcome = await report;
    if (_disposed) return;
    switch (outcome) {
      case RiderLocationReport.posted:
        _locationNoticeShown = false;
      case RiderLocationReport.permissionDenied:
        _notifyLocation(
          'Enable location access so nearby deliveries can find you.',
        );
      case RiderLocationReport.permissionPermanentlyDenied:
        _notifyLocation(
          'Location access is permanently blocked. Allow it in Settings to '
          'receive nearby deliveries.',
        );
      case RiderLocationReport.locationUnavailable:
      case RiderLocationReport.failed:
        break;
    }
  }

  void _notifyLocation(String message) {
    if (_locationNoticeShown) return;
    _locationNoticeShown = true;
    errorMessage = message;
    notifyListeners();
  }

  void _startOfferPoll() {
    _offerPollTimer?.cancel();
    _offerPollTimer = Timer.periodic(
      _offerFallbackPollInterval,
      (_) => unawaited(_pollForOffers()),
    );
  }

  void _stopOfferPoll() {
    _offerPollTimer?.cancel();
    _offerPollTimer = null;
  }

  /// Bounded fallback: only polls when the socket is not delivering offers.
  Future<void> _pollForOffers() async {
    final realtime = _realtime;
    if (_disposed || user == null) return;
    if (realtime != null && realtime.state == RiderRealtimeState.connected) {
      return;
    }
    if (!(profile?.isOnline ?? false)) return;
    if (activeDelivery != null) return;
    unawaited(reconcileOffers());
  }

  String _messageFor(Object error) => switch (error) {
    RiderApiException exception => exception.message,
    FormatException _ => 'The server returned unexpected rider data.',
    _ => 'Unable to reach TalaDelivery. Please try again.',
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
