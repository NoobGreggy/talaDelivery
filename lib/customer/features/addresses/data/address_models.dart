part of '../../../app.dart';

class CustomerAddressRequest {
  const CustomerAddressRequest({
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.province,
    this.label,
    this.barangay,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.notes,
    this.isDefault = false,
  });

  final String recipientName;
  final String phone;
  final String addressLine;
  final String city;
  final String province;
  final String? label;
  final String? barangay;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
    'label': _emptyToNull(label),
    'recipient_name': recipientName.trim(),
    'phone': phone.trim(),
    'address_line': addressLine.trim(),
    'barangay': _emptyToNull(barangay),
    'city': city.trim(),
    'province': province.trim(),
    'postal_code': _emptyToNull(postalCode),
    'latitude': latitude,
    'longitude': longitude,
    'notes': _emptyToNull(notes),
    'is_default': isDefault,
  };

  static String? _emptyToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.province,
    required this.isDefault,
    this.label,
    this.barangay,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final int id;
  final String? label;
  final String recipientName;
  final String phone;
  final String addressLine;
  final String? barangay;
  final String city;
  final String province;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDefault;

  String get formatted =>
      [addressLine, ?barangay, city, province, ?postalCode].join(', ');

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': int id,
        'recipient_name': String recipientName,
        'phone': String phone,
        'address_line': String addressLine,
        'city': String city,
        'province': String province,
        'is_default': bool isDefault,
      } =>
        CustomerAddress(
          id: id,
          label: json['label'] as String?,
          recipientName: recipientName,
          phone: phone,
          addressLine: addressLine,
          barangay: json['barangay'] as String?,
          city: city,
          province: province,
          postalCode: json['postal_code'] as String?,
          latitude: json['latitude'] == null
              ? null
              : _jsonDouble(json['latitude']),
          longitude: json['longitude'] == null
              ? null
              : _jsonDouble(json['longitude']),
          notes: json['notes'] as String?,
          isDefault: isDefault,
        ),
      _ => throw const FormatException('Invalid customer address response.'),
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'recipient_name': recipientName,
    'phone': phone,
    'address_line': addressLine,
    'barangay': barangay,
    'city': city,
    'province': province,
    'postal_code': postalCode,
    'latitude': latitude,
    'longitude': longitude,
    'notes': notes,
    'is_default': isDefault,
  };
}
