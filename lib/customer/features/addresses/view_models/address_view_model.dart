part of '../../../app.dart';

class CustomerAddressViewModel extends ChangeNotifier {
  CustomerAddressViewModel(this._repository);

  final CustomerAddressRepository _repository;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? fieldError(String field) => _fieldErrors[field];

  Future<CustomerAddress?> create(CustomerAddressRequest request) async {
    return _run(() => _repository.create(request));
  }

  Future<CustomerAddress?> update(int id, CustomerAddressRequest request) =>
      _run(() => _repository.update(id, request));

  Future<CustomerAddress?> _run(
    Future<CustomerAddress> Function() operation,
  ) async {
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
      _errorMessage = 'The server returned unexpected address data.';
      return null;
    } catch (_) {
      _errorMessage = 'Unable to save the address. Please try again.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
