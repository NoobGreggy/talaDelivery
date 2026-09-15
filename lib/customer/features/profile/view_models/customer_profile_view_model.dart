part of '../../../app.dart';

class CustomerProfileViewModel extends ChangeNotifier {
  CustomerProfileViewModel(this._repository);

  final CustomerAuthRepository _repository;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? fieldError(String field) => _fieldErrors[field];

  Future<CustomerUser?> update({
    required String name,
    required String email,
    String? phone,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();
    try {
      return await _repository.updateProfile(
        name: name,
        email: email,
        phone: phone,
      );
    } on CustomerApiException catch (error) {
      _errorMessage = error.message;
      _fieldErrors = error.fieldErrors;
      return null;
    } on FormatException {
      _errorMessage = 'The server returned unexpected profile data.';
      return null;
    } catch (_) {
      _errorMessage = 'Unable to update your profile. Please try again.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
