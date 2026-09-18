part of '../../../app.dart';

abstract class CustomerCatalogRepository {
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
    return StoreData.fromJson(_payloadMap(payload));
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
