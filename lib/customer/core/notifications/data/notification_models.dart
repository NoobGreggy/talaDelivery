part of '../../../app.dart';

class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.messageText,
    required this.isRead,
    this.createdAt,
    this.data = const {},
  });

  final int id;
  final String type;
  final String title;
  final String messageText;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  int? get orderId =>
      data['order_id'] == null ? null : _jsonInt(data['order_id']);

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['id']);
    if (id <= 0) {
      throw const FormatException('Invalid notification response.');
    }
    return CustomerNotification(
      id: id,
      type: _jsonString(json['type']) ?? 'general',
      title: _jsonString(json['title']) ?? 'Notification',
      messageText: _jsonString(json['message']) ?? '',
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : const {},
    );
  }
}
