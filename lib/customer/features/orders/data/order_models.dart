part of '../../../app.dart';

class CustomerRiderLocation {
  const CustomerRiderLocation({
    required this.deliveryId,
    this.riderId,
    this.latitude,
    this.longitude,
    this.recordedAt,
    this.sequence = 0,
    this.accuracy,
    this.heading,
    this.speed,
  });

  final int deliveryId;
  final int? riderId;
  final double? latitude;
  final double? longitude;
  final DateTime? recordedAt;
  final int sequence;
  final double? accuracy;
  final double? heading;
  final double? speed;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory CustomerRiderLocation.fromJson(
    Map<String, dynamic> json, {
    int? deliveryId,
  }) => CustomerRiderLocation(
    deliveryId: deliveryId ?? _jsonInt(json['delivery_id']),
    riderId: json['rider_id'] == null ? null : _jsonInt(json['rider_id']),
    latitude: json['latitude'] == null ? null : _jsonDouble(json['latitude']),
    longitude: json['longitude'] == null
        ? null
        : _jsonDouble(json['longitude']),
    recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? ''),
    sequence: _jsonInt(json['sequence']),
    accuracy: json['accuracy_m'] == null
        ? null
        : _jsonDouble(json['accuracy_m']),
    heading: json['heading_deg'] == null
        ? null
        : _jsonDouble(json['heading_deg']),
    speed: json['speed_mps'] == null ? null : _jsonDouble(json['speed_mps']),
  );

  Map<String, dynamic> toJson() => {
    'delivery_id': deliveryId,
    'rider_id': riderId,
    'latitude': latitude,
    'longitude': longitude,
    'recorded_at': recordedAt?.toIso8601String(),
    'sequence': sequence,
    'accuracy_m': accuracy,
    'heading_deg': heading,
    'speed_mps': speed,
  };
}

class CustomerDelivery {
  const CustomerDelivery({
    required this.id,
    required this.status,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.riderLocation,
  });

  final int id;
  final String status;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final CustomerRiderLocation? riderLocation;

  CustomerMapPoint? get pickupPoint =>
      pickupLatitude == null || pickupLongitude == null
      ? null
      : CustomerMapPoint(pickupLatitude!, pickupLongitude!);
  CustomerMapPoint? get deliveryPoint =>
      deliveryLatitude == null || deliveryLongitude == null
      ? null
      : CustomerMapPoint(deliveryLatitude!, deliveryLongitude!);
  bool get isTrackable => const {
    'ASSIGNED',
    'ACCEPTED',
    'PICKED_UP',
    'IN_TRANSIT',
  }.contains(status);

  factory CustomerDelivery.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['id']);
    if (id <= 0) throw const FormatException('Invalid delivery response.');
    final location = json['rider_location'];
    return CustomerDelivery(
      id: id,
      status: _jsonString(json['status']) ?? 'UNASSIGNED',
      pickupLatitude: json['pickup_latitude'] == null
          ? null
          : _jsonDouble(json['pickup_latitude']),
      pickupLongitude: json['pickup_longitude'] == null
          ? null
          : _jsonDouble(json['pickup_longitude']),
      deliveryLatitude: json['delivery_latitude'] == null
          ? null
          : _jsonDouble(json['delivery_latitude']),
      deliveryLongitude: json['delivery_longitude'] == null
          ? null
          : _jsonDouble(json['delivery_longitude']),
      riderLocation: location is Map<String, dynamic>
          ? CustomerRiderLocation.fromJson(location, deliveryId: id)
          : null,
    );
  }
}

class CustomerOrderItem {
  const CustomerOrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final int id;
  final int? productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) =>
      CustomerOrderItem(
        id: _jsonInt(json['id']),
        productId: json['product_id'] == null
            ? null
            : _jsonInt(json['product_id']),
        name: _jsonString(json['product_name']) ?? 'Product',
        quantity: _jsonInt(json['quantity']),
        unitPrice: _jsonDouble(json['unit_price']),
        subtotal: _jsonDouble(json['subtotal']),
      );
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.deliveryAddress,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.notes,
    this.store,
    this.delivery,
    this.items = const [],
  });

  final int id;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final String paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String? customerName;
  final String? customerPhone;
  final String deliveryAddress;
  final String? notes;
  final DateTime? createdAt;
  final StoreData? store;
  final CustomerDelivery? delivery;
  final List<CustomerOrderItem> items;

  bool get isCancelled => status == 'CANCELLED';
  bool get isDelivered => status == 'DELIVERED';
  bool get isPending => status == 'PENDING';

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['id']);
    final number = _jsonString(json['order_number']);
    if (id <= 0 || number == null) {
      throw const FormatException('Invalid order response.');
    }
    final storeJson = json['store'];
    final deliveryJson = json['delivery'];
    return CustomerOrder(
      id: id,
      orderNumber: number,
      status: _jsonString(json['status']) ?? 'PENDING',
      statusLabel: _jsonString(json['status_label']) ?? 'Pending',
      paymentMethod: _jsonString(json['payment_method']) ?? 'COD',
      subtotal: _jsonDouble(json['subtotal']),
      deliveryFee: _jsonDouble(json['delivery_fee']),
      discount: _jsonDouble(json['discount']),
      total: _jsonDouble(json['total']),
      customerName: _jsonString(json['customer_name']),
      customerPhone: _jsonString(json['customer_phone']),
      deliveryAddress: _jsonString(json['delivery_address']) ?? '',
      notes: _jsonString(json['notes']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      store: storeJson is Map<String, dynamic>
          ? StoreData.fromJson(storeJson)
          : null,
      delivery: deliveryJson is Map<String, dynamic>
          ? CustomerDelivery.fromJson(deliveryJson)
          : null,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CustomerOrderItem.fromJson)
          .toList(growable: false),
    );
  }
}

String shortDate(DateTime? date) {
  if (date == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
