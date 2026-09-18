part of '../../app.dart';

double _jsonDouble(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text) ?? 0,
  _ => 0,
};

int _jsonInt(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text) ?? 0,
  _ => 0,
};

String? _jsonString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

List<dynamic> _payloadList(Map<String, dynamic> payload) {
  final data = payload['data'];
  return switch (data) {
    List<dynamic> values => values,
    {'data': List<dynamic> values} => values,
    _ => throw const CustomerApiException('The server list is invalid.'),
  };
}

Future<List<dynamic>> _allPages(
  CustomerApiClient api,
  String path, {
  bool authenticated = true,
}) async {
  final uri = Uri.parse(path);
  final results = <dynamic>[];
  final seenIds = <int>{};
  for (var page = 1; page <= 1000; page++) {
    final pageUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'per_page': '100',
        'page': '$page',
      },
    );
    final payload = await api.get(
      pageUri.toString(),
      authenticated: authenticated,
    );
    final items = _payloadList(payload);
    for (final item in items) {
      final id = item is Map<String, dynamic> ? _jsonInt(item['id']) : 0;
      if (id <= 0 || seenIds.add(id)) results.add(item);
    }
    final wrapped = payload['data'];
    final meta = wrapped is Map<String, dynamic> ? wrapped['meta'] : null;
    final lastPage = meta is Map<String, dynamic>
        ? _jsonInt(meta['last_page'])
        : 0;
    if (lastPage <= page || items.isEmpty) return results;
  }
  throw const CustomerApiException(
    'Too many result pages. Narrow your search.',
  );
}

Map<String, dynamic> _payloadMap(Map<String, dynamic> payload) {
  final data = payload['data'];
  if (data is Map<String, dynamic>) return data;
  throw const CustomerApiException('The server response is missing data.');
}

class StoreData {
  const StoreData({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.phone,
    this.email,
    this.address,
    this.openingTime,
    this.closingTime,
    this.categories = const [],
    this.products = const [],
  });

  final int id;
  final String name;
  final String status;
  final String? description;
  final String? phone;
  final String? email;
  final String? address;
  final String? openingTime;
  final String? closingTime;
  final List<CategoryData> categories;
  final List<ProductData> products;

  bool get open => status.toUpperCase() == 'ACTIVE';
  IconData get icon => Icons.storefront_rounded;
  Color get color => sky;

  factory StoreData.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['id']);
    final name = _jsonString(json['name']);
    if (id <= 0 || name == null) {
      throw const FormatException('Invalid store response.');
    }
    return StoreData(
      id: id,
      name: name,
      status: _jsonString(json['status']) ?? 'INACTIVE',
      description: _jsonString(json['description']),
      phone: _jsonString(json['phone']),
      email: _jsonString(json['email']),
      address: _jsonString(json['address']),
      openingTime: _jsonString(json['opening_time']),
      closingTime: _jsonString(json['closing_time']),
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CategoryData.fromJson)
          .toList(growable: false),
      products: (json['products'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProductData.fromJson)
          .toList(growable: false),
    );
  }
}

class CategoryData {
  const CategoryData({
    required this.id,
    required this.storeId,
    required this.name,
    required this.status,
    this.description,
  });

  final int id;
  final int storeId;
  final String name;
  final String status;
  final String? description;

  factory CategoryData.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['id']);
    final name = _jsonString(json['name']);
    if (id <= 0 || name == null) {
      throw const FormatException('Invalid category response.');
    }
    return CategoryData(
      id: id,
      storeId: _jsonInt(json['store_id']),
      name: name,
      status: _jsonString(json['status']) ?? 'INACTIVE',
      description: _jsonString(json['description']),
    );
  }
}

class ProductData {
  const ProductData({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.stock,
    required this.available,
    this.categoryId,
    this.description,
    this.image,
  });

  final int id;
  final int storeId;
  final int? categoryId;
  final String name;
  final String? description;
  final double price;
  final String? image;
  final int stock;
  final bool available;

  IconData get icon => Icons.inventory_2_outlined;
  Color get color => sky;

  factory ProductData.fromJson(Map<String, dynamic> json) {
    final id = _jsonInt(json['id']);
    final storeId = _jsonInt(json['store_id']);
    final name = _jsonString(json['name']);
    if (id <= 0 || storeId <= 0 || name == null) {
      throw const FormatException('Invalid product response.');
    }
    return ProductData(
      id: id,
      storeId: storeId,
      categoryId: json['category_id'] == null
          ? null
          : _jsonInt(json['category_id']),
      name: name,
      description: _jsonString(json['description']),
      price: _jsonDouble(json['price']),
      image: _jsonString(json['image']),
      stock: _jsonInt(json['stock']),
      available: json['is_available'] == true && _jsonInt(json['stock']) > 0,
    );
  }
}

String peso(num value) {
  final amount = value.toDouble();
  return amount == amount.roundToDouble()
      ? '₱${amount.toStringAsFixed(0)}'
      : '₱${amount.toStringAsFixed(2)}';
}
