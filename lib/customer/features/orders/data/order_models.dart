part of '../../../app.dart';

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
