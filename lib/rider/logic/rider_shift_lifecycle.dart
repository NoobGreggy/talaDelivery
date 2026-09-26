part of '../app.dart';

extension _RiderShiftLifecycle on RiderAppController {
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
        _notifyControllerListeners();
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
    unawaited(_handleLocationReport(location.reportOnce()));
    location.start(reportImmediately: false);
  }

  Future<void> _handleLocationReport(Future<RiderLocationReport> report) async {
    final outcome = await report;
    if (_disposed) return;
    switch (outcome) {
      case RiderLocationReport.posted:
        _locationNoticeShown = false;
      case RiderLocationReport.unchanged:
        _locationNoticeShown = false;
      case RiderLocationReport.lowAccuracy:
        _notifyLocation(
          'Your GPS accuracy is low. Move to an open area for more reliable '
          'tracking.',
        );
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
        _notifyLocation(
          'Location services are unavailable. Enable GPS to continue tracking.',
        );
      case RiderLocationReport.failed:
        break;
    }
  }

  void _notifyLocation(String message) {
    if (_locationNoticeShown) return;
    _locationNoticeShown = true;
    errorMessage = message;
    _notifyControllerListeners();
  }

  void _startOfferPoll() {
    _offerPollTimer?.cancel();
    _offerPollTimer = Timer.periodic(
      RiderAppController._offerFallbackPollInterval,
      (_) => unawaited(_pollForOffers()),
    );
  }

  void _stopOfferPoll() {
    _offerPollTimer?.cancel();
    _offerPollTimer = null;
  }

  /// Reconcile occasionally even with a connected socket: events published
  /// while the queue or app was unavailable cannot be replayed by Reverb.
  Future<void> _pollForOffers() async {
    if (_disposed || user == null) return;
    if (!(profile?.isOnline ?? false)) return;
    if (activeDelivery != null) return;
    await reconcileOffers();
  }
}
