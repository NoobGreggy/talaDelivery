part of '../../../app.dart';

class CustomerAuthViewModel extends ChangeNotifier {
  CustomerAuthViewModel(this._repository);

  final CustomerAuthRepository _repository;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? fieldError(String field) => _fieldErrors[field];

  Future<CustomerUser?> login({
    required String email,
    required String password,
  }) => _run(() => _repository.login(email: email, password: password));

  Future<CustomerUser?> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) => _run(
    () => _repository.register(
      name: name,
      email: email,
      password: password,
      phone: phone,
    ),
  );

  Future<CustomerUser?> _run(Future<CustomerUser> Function() operation) async {
    _isSubmitting = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();
    try {
      return await operation();
    } on CustomerApiException catch (error) {
      _errorMessage = error.message;
      _fieldErrors = error.fieldErrors;
      return null;
    } on FormatException {
      _errorMessage = 'The server returned unexpected account data.';
      return null;
    } catch (_) {
      _errorMessage = 'Unable to reach TalaDelivery. Please try again.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
