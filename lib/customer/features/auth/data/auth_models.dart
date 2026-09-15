part of '../../../app.dart';

class CustomerUser {
  const CustomerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;

  factory CustomerUser.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': int id,
        'name': String name,
        'email': String email,
        'role': String role,
      } =>
        CustomerUser(
          id: id,
          name: name,
          email: email,
          role: role,
          phone: json['phone'] as String?,
        ),
      _ => throw const FormatException('Invalid customer user response.'),
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
  };
}

class CustomerAuthResult {
  const CustomerAuthResult({required this.token, required this.user});

  final String token;
  final CustomerUser user;

  factory CustomerAuthResult.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'token': String token, 'user': Map<String, dynamic> user} =>
        CustomerAuthResult(token: token, user: CustomerUser.fromJson(user)),
      _ => throw const FormatException('Invalid authentication response.'),
    };
  }

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}
