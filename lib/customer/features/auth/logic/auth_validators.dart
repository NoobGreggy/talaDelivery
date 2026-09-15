part of '../../../app.dart';

class CustomerValidators {
  const CustomerValidators._();

  static String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  static String? name(String? value) {
    final required = requiredText(value, 'Full name');
    if (required != null) return required;
    if (value!.trim().length < 2) return 'Enter your full name.';
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, 'Email');
    if (required != null) return required;
    final normalized = value!.trim();
    final valid = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
    ).hasMatch(normalized);
    return valid ? null : 'Enter a valid email address.';
  }

  static String? password(String? value) {
    final required = requiredText(value, 'Password');
    if (required != null) return required;
    return value!.length >= 8
        ? null
        : 'Password must be at least 8 characters.';
  }

  static String? confirmPassword(String? value, String password) {
    final required = requiredText(value, 'Password confirmation');
    if (required != null) return required;
    return value == password ? null : 'Passwords do not match.';
  }

  static String? phone(String? value, {bool required = false}) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return required ? 'Phone number is required.' : null;
    }
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10 && digits.length <= 15
        ? null
        : 'Enter a valid phone number.';
  }
}
