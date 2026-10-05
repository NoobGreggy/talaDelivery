part of '../../../app.dart';

class CustomerDeliveryQuote {
  const CustomerDeliveryQuote({
    required this.deliveryFee,
    required this.distanceKm,
    required this.zoneName,
  });
  final double deliveryFee;
  final double distanceKm;
  final String zoneName;

  factory CustomerDeliveryQuote.fromJson(Map<String, dynamic> json) {
    final fee = double.tryParse('${json['deliveryFee']}');
    final distance = double.tryParse('${json['distanceKm']}');
    final zone = json['zone'];
    if (fee == null ||
        !fee.isFinite ||
        fee < 0 ||
        distance == null ||
        !distance.isFinite ||
        distance < 0 ||
        zone is! Map<String, dynamic>) {
      throw const CustomerApiException('The delivery fee response is invalid.');
    }
    return CustomerDeliveryQuote(
      deliveryFee: fee,
      distanceKm: distance,
      zoneName: _jsonString(zone['name']) ?? 'Delivery zone',
    );
  }
}

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

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  factory CustomerRiderLocation.fromJson(
    Map<String, dynamic> json, {
    int? deliveryId,
  }) => CustomerRiderLocation(
    deliveryId:
        deliveryId ?? _jsonInt(json['delivery_id'] ?? json['deliveryId']),
    riderId: (json['rider_id'] ?? json['riderId']) == null
        ? null
        : _jsonInt(json['rider_id'] ?? json['riderId']),
    latitude: double.tryParse('${json['latitude']}'),
    longitude: json['longitude'] == null
        ? null
        : double.tryParse('${json['longitude']}'),
    recordedAt: DateTime.tryParse(
      (json['recorded_at'] ?? json['timestamp'])?.toString() ?? '',
    ),
    sequence: _jsonInt(json['sequence']),
    accuracy: (json['accuracy_m'] ?? json['accuracyM']) == null
        ? null
        : _jsonDouble(json['accuracy_m'] ?? json['accuracyM']),
    heading: (json['heading_deg'] ?? json['headingDeg']) == null
        ? null
        : _jsonDouble(json['heading_deg'] ?? json['headingDeg']),
    speed: (json['speed_mps'] ?? json['speedMps']) == null
        ? null
        : _jsonDouble(json['speed_mps'] ?? json['speedMps']),
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

  factory CustomerOrderItem.fromJson(
    Map<String, dynamic> json,
  ) => CustomerOrderItem(
    id: _jsonInt(json['id']),
    productId: (json['product_id'] ?? json['productId']) == null
        ? null
        : _jsonInt(json['product_id'] ?? json['productId']),
    name: _jsonString(json['product_name'] ?? json['productName']) ?? 'Product',
    quantity: _jsonInt(json['quantity']),
    unitPrice: _jsonDouble(json['unit_price'] ?? json['unitPrice']),
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
    final number = _jsonString(json['order_number'] ?? json['orderNumber']);
    if (id <= 0 || number == null) {
      throw const FormatException('Invalid order response.');
    }
    final storeJson =
        json['store'] ??
        (json['storeId'] == null
            ? null
            : {
                'id': json['storeId'],
                'name': json['storeName'] ?? 'Store #${json['storeId']}',
                'status': 'ACTIVE',
              });
    final deliveryJson = json['delivery'];
    return CustomerOrder(
      id: id,
      orderNumber: number,
      status: _jsonString(json['status']) ?? 'PENDING',
      statusLabel:
          _jsonString(json['status_label']) ??
          (json['status']?.toString().replaceAll('_', ' ') ?? 'Pending'),
      paymentMethod:
          _jsonString(json['payment_method'] ?? json['paymentMethod']) ?? 'COD',
      subtotal: _jsonDouble(json['subtotal']),
      deliveryFee: _jsonDouble(json['delivery_fee'] ?? json['deliveryFee']),
      discount: _jsonDouble(json['discount']),
      total: _jsonDouble(json['total']),
      customerName: _jsonString(json['customer_name'] ?? json['customerName']),
      customerPhone: _jsonString(
        json['customer_phone'] ?? json['customerPhone'],
      ),
      deliveryAddress:
          _jsonString(json['delivery_address'] ?? json['deliveryAddress']) ??
          '',
      notes: _jsonString(json['notes']),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'])?.toString() ?? '',
      ),
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
