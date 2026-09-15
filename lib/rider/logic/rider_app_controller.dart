part of '../app.dart';

class RiderAppController extends ChangeNotifier {
  RiderAppController(this._repository);

  final RiderRepository _repository;
  RiderUser? user;
  RiderProfile? profile;
  List<RiderOffer> offers = const [];
  List<RiderDelivery> deliveries = const [];
  RiderDelivery? activeDelivery;
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;
  Map<String, String> fieldErrors = const {};

  List<RiderDelivery> get completedDeliveries => deliveries
      .where((delivery) => delivery.isDelivered)
      .toList(growable: false);

  Future<bool> restore() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.restoreSession();
      if (user == null) return false;
      await _loadData();
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

  Future<bool> setOnline(bool value) async => _runMutation(() async {
    profile = await _repository.setOnline(value);
    if (value) offers = await _repository.offers();
  });

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
    try {
      await _repository.logout();
    } finally {
      user = null;
      profile = null;
      offers = const [];
      deliveries = const [];
      activeDelivery = null;
      errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    profile = await _repository.profile();
    await _reloadDeliveries();
    offers = profile!.isOnline ? await _repository.offers() : const [];
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

  String _messageFor(Object error) => switch (error) {
    RiderApiException exception => exception.message,
    FormatException _ => 'The server returned unexpected rider data.',
    _ => 'Unable to reach TalaDelivery. Please try again.',
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
