part of '../../../app.dart';

abstract class CustomerCatalogRepository {
  Future<List<CategoryData>> listCategories();
  Future<List<StoreData>> listStores({String? search});
  Future<StoreData> getStore(int id);
  Future<List<ProductData>> listProducts({
    int? storeId,
    int? categoryId,
    String? search,
  });
}

class ApiCustomerCatalogRepository implements CustomerCatalogRepository {
  ApiCustomerCatalogRepository(this._apiClient);

  final CustomerApiClient _apiClient;

  @override
  Future<List<CategoryData>> listCategories() async {
    final payload = await _apiClient.get(
      'store-categories',
      authenticated: false,
    );
    return _payloadList(payload)
        .whereType<Map<String, dynamic>>()
        .map(CategoryData.fromJson)
        .where((category) => category.status == 'ACTIVE')
        .toList();
  }

  @override
  Future<List<StoreData>> listStores({String? search}) async {
    final query = <String, String>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final items = await _allPages(
      _apiClient,
      Uri(path: 'stores', queryParameters: query).toString(),
      authenticated: false,
    );
    return items
        .whereType<Map<String, dynamic>>()
        .map(StoreData.fromJson)
        .toList(growable: false);
  }

  @override
  Future<StoreData> getStore(int id) async {
    final payload = await _apiClient.get('stores/$id', authenticated: false);
    final store = _payloadMap(payload);
    if (store['products'] is List) return StoreData.fromJson(store);
    final results = await Future.wait<dynamic>([
      _apiClient.get('stores/$id/categories', authenticated: false),
      _allPages(_apiClient, 'products?store_id=$id', authenticated: false),
    ]);
    return StoreData.fromJson({
      ...store,
      'categories': _payloadList(results[0] as Map<String, dynamic>),
      'products': results[1] as List<dynamic>,
    });
  }

  @override
  Future<List<ProductData>> listProducts({
    int? storeId,
    int? categoryId,
    String? search,
  }) async {
    final query = <String, String>{
      if (storeId != null) 'store_id': '$storeId',
      if (categoryId != null) 'category_id': '$categoryId',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final items = await _allPages(
      _apiClient,
      Uri(path: 'products', queryParameters: query).toString(),
      authenticated: false,
    );
    return items
        .whereType<Map<String, dynamic>>()
        .map(ProductData.fromJson)
        .toList(growable: false);
  }
}
