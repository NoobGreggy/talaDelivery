part of '../app.dart';

class RiderWalletController extends ChangeNotifier {
  RiderWalletController(this.repository);
  final RiderRepository repository;
  RiderWallet? wallet;
  List<RiderWalletTransaction> transactions = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  String? historyError;
  int _page = 0;
  int _lastPage = 1;
  bool _disposed = false;
  bool get hasMore => _page > 0 && _page < _lastPage;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (isLoading || isLoadingMore) return;
    isLoading = true;
    error = null;
    historyError = null;
    _notify();
    // Independent failures preserve the other section and previously loaded data.
    await Future.wait([
      (() async {
        try {
          wallet = await repository.wallet();
        } catch (_) {
          error = 'Could not refresh your balance. Please retry.';
        }
      })(),
      (() async {
        try {
          final result = await repository.walletTransactions();
          transactions = result.items;
          _page = 1;
          _lastPage = result.lastPage;
        } catch (_) {
          historyError = 'Could not refresh wallet activity. Please retry.';
        }
      })(),
    ]);
    isLoading = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    historyError = null;
    _notify();
    try {
      final result = await repository.walletTransactions(page: _page + 1);
      final ids = transactions.map((t) => t.id).toSet();
      transactions = [
        ...transactions,
        ...result.items.where((t) => ids.add(t.id)),
      ];
      _page += 1;
      _lastPage = result.lastPage;
    } catch (_) {
      historyError = 'Could not load more activity. Please retry.';
    }
    isLoadingMore = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
