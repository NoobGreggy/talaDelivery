part of '../../app.dart';

class CustomerMapPoint {
  const CustomerMapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class CustomerResolvedAddress {
  const CustomerResolvedAddress({
    required this.formattedAddress,
    this.street,
    this.barangay,
    this.city,
    this.province,
    this.postalCode,
    this.country,
  });

  final String formattedAddress;
  final String? street;
  final String? barangay;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? country;
}
