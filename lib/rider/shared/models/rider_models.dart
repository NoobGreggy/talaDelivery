part of '../../app.dart';

double _riderDouble(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text) ?? 0,
  _ => 0,
};

int _riderInt(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text) ?? 0,
  _ => 0,
};

String? _riderString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

Map<String, dynamic> _riderPayloadMap(Map<String, dynamic> payload) {
  final data = payload['data'];
  if (data is Map<String, dynamic>) return data;
  throw const RiderApiException('The server response is missing data.');
}

List<dynamic> _riderPayloadList(Map<String, dynamic> payload) {
  final data = payload['data'];
  return switch (data) {
    List<dynamic> values => values,
    {'data': List<dynamic> values} => values,
    _ => throw const RiderApiException('The server list is invalid.'),
  };
}

class RiderUser {
  const RiderUser({
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

  factory RiderUser.fromJson(Map<String, dynamic> json) {
    final id = _riderInt(json['id']);
    final name = _riderString(json['name']);
    final email = _riderString(json['email']);
    final role = _riderString(json['role']);
    if (id <= 0 || name == null || email == null || role == null) {
      throw const FormatException('Invalid rider account response.');
    }
    return RiderUser(
      id: id,
      name: name,
      email: email,
      role: role,
      phone: _riderString(json['phone']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
  };
}

class RiderStore {
  const RiderStore({required this.id, required this.name, this.address});
  final int id;
  final String name;
  final String? address;

  factory RiderStore.fromJson(Map<String, dynamic> json) => RiderStore(
    id: _riderInt(json['id']),
    name: _riderString(json['name']) ?? 'Store',
    address: _riderString(json['address']),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'address': address};
}

class RiderOrder {
  const RiderOrder({
    required this.number,
    required this.total,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
    this.notes,
  });
  final String number;
  final double total;
  final String paymentMethod;
  final String? customerName;
  final String? customerPhone;
  final String? notes;

  factory RiderOrder.fromJson(Map<String, dynamic> json) => RiderOrder(
    number: _riderString(json['order_number']) ?? '#${_riderInt(json['id'])}',
    total: _riderDouble(json['total']),
    paymentMethod: _riderString(json['payment_method']) ?? 'COD',
    customerName: _riderString(json['customer_name']),
    customerPhone: _riderString(json['customer_phone']),
    notes: _riderString(json['notes']),
  );

  Map<String, dynamic> toJson() => {
    'order_number': number,
    'total': total,
    'payment_method': paymentMethod,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'notes': notes,
  };
}

class RiderDelivery {
  const RiderDelivery({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.distanceKm,
    required this.deliveryFee,
    required this.createdAt,
    this.store,
    this.order,
  });

  final int id;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final double distanceKm;
  final double deliveryFee;
  final DateTime? createdAt;
  final RiderStore? store;
  final RiderOrder? order;

  bool get isDelivered => status == 'DELIVERED';
  bool get isActive => const {
    'ASSIGNED',
    'ACCEPTED',
    'PICKED_UP',
    'IN_TRANSIT',
  }.contains(status);
  String get displayNumber => order?.number ?? '#DEL-$id';

  factory RiderDelivery.fromJson(Map<String, dynamic> json) {
    final id = _riderInt(json['id']);
    if (id <= 0) throw const FormatException('Invalid delivery response.');
    final store = json['store'];
    final order = json['order'];
    return RiderDelivery(
      id: id,
      status: _riderString(json['status']) ?? 'UNASSIGNED',
      pickupAddress: _riderString(json['pickup_address']) ?? '',
      deliveryAddress: _riderString(json['delivery_address']) ?? '',
      distanceKm: _riderDouble(json['distance_km']),
      deliveryFee: _riderDouble(json['delivery_fee']),
      createdAt: DateTime.tryParse(
        (json['delivered_at'] ?? json['created_at'])?.toString() ?? '',
      ),
      store: store is Map<String, dynamic> ? RiderStore.fromJson(store) : null,
      order: order is Map<String, dynamic> ? RiderOrder.fromJson(order) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'pickup_address': pickupAddress,
    'delivery_address': deliveryAddress,
    'distance_km': distanceKm,
    'delivery_fee': deliveryFee,
    'created_at': createdAt?.toIso8601String(),
    'store': store?.toJson(),
    'order': order?.toJson(),
  };
}

class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.user,
    required this.vehicleType,
    required this.isOnline,
    required this.status,
    required this.completedDeliveries,
    required this.totalEarnings,
    this.vehiclePlate,
    this.licenseNumber,
    this.currentDelivery,
  });

  final int id;
  final RiderUser user;
  final String vehicleType;
  final String? vehiclePlate;
  final String? licenseNumber;
  final bool isOnline;
  final String status;
  final int completedDeliveries;
  final double totalEarnings;
  final RiderDelivery? currentDelivery;

  bool get canGoOnline =>
      !const {'PENDING', 'REJECTED', 'SUSPENDED'}.contains(status);

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Rider profile has no account.');
    }
    final current = json['current_delivery'];
    return RiderProfile(
      id: _riderInt(json['id']),
      user: RiderUser.fromJson(user),
      vehicleType: _riderString(json['vehicle_type']) ?? 'Not set',
      vehiclePlate: _riderString(json['vehicle_plate']),
      licenseNumber: _riderString(json['license_number']),
      isOnline: json['is_online'] == true,
      status: _riderString(json['status']) ?? 'PENDING',
      completedDeliveries: _riderInt(json['completed_deliveries']),
      totalEarnings: _riderDouble(json['total_earnings']),
      currentDelivery: current is Map<String, dynamic>
          ? RiderDelivery.fromJson(current)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user.toJson(),
    'vehicle_type': vehicleType,
    'vehicle_plate': vehiclePlate,
    'license_number': licenseNumber,
    'is_online': isOnline,
    'status': status,
    'completed_deliveries': completedDeliveries,
    'total_earnings': totalEarnings,
    'current_delivery': currentDelivery?.toJson(),
  };
}

class RiderOffer {
  const RiderOffer({
    required this.id,
    required this.status,
    required this.expiresAt,
    required this.delivery,
  });
  final int id;
  final String status;
  final DateTime? expiresAt;
  final RiderDelivery delivery;

  int get secondsRemaining {
    if (expiresAt == null) return 0;
    final seconds = expiresAt!.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  factory RiderOffer.fromJson(Map<String, dynamic> json) {
    final delivery = json['delivery'];
    if (delivery is! Map<String, dynamic>) {
      throw const FormatException('Offer has no delivery.');
    }
    return RiderOffer(
      id: _riderInt(json['id']),
      status: _riderString(json['status']) ?? 'PENDING',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      delivery: RiderDelivery.fromJson(delivery),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'expires_at': expiresAt?.toIso8601String(),
    'delivery': delivery.toJson(),
  };
}

class RiderAuthResult {
  const RiderAuthResult({required this.token, required this.user});
  final String token;
  final RiderUser user;

  factory RiderAuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (json['token'] is! String || user is! Map<String, dynamic>) {
      throw const FormatException('Invalid authentication response.');
    }
    return RiderAuthResult(
      token: json['token'] as String,
      user: RiderUser.fromJson(user),
    );
  }

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}
