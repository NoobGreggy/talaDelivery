import 'package:tala_delivery_customer/main.dart';

class FakeCustomerAuthRepository implements CustomerAuthRepository {
  int loginCalls = 0;
  int registerCalls = 0;
  int logoutCalls = 0;
  int updateProfileCalls = 0;
  CustomerUser? restoredUser;

  @override
  Future<CustomerUser> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    return CustomerUser(
      id: 1,
      name: 'Test Customer',
      email: email,
      role: 'customer',
    );
  }

  @override
  Future<CustomerUser> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    registerCalls++;
    return CustomerUser(
      id: 1,
      name: name,
      email: email,
      phone: phone,
      role: 'customer',
    );
  }

  @override
  Future<CustomerUser?> restoreSession() async => restoredUser;

  @override
  Future<CustomerUser> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    updateProfileCalls++;
    return CustomerUser(
      id: 1,
      name: name,
      email: email,
      phone: phone,
      role: 'customer',
    );
  }

  @override
  Future<void> logout() async => logoutCalls++;
}

class FakeCustomerAddressRepository implements CustomerAddressRepository {
  int createCalls = 0;
  List<CustomerAddress> addresses = [];

  @override
  Future<CustomerAddress> create(CustomerAddressRequest request) async {
    createCalls++;
    final address = CustomerAddress(
      id: createCalls,
      label: request.label,
      recipientName: request.recipientName,
      phone: request.phone,
      addressLine: request.addressLine,
      barangay: request.barangay,
      city: request.city,
      province: request.province,
      postalCode: request.postalCode,
      latitude: request.latitude,
      longitude: request.longitude,
      notes: request.notes,
      isDefault: request.isDefault,
    );
    addresses = [...addresses, address];
    return address;
  }

  @override
  Future<List<CustomerAddress>> list() async => addresses;

  @override
  Future<CustomerAddress> update(int id, CustomerAddressRequest request) async {
    final updated = CustomerAddress(
      id: id,
      label: request.label,
      recipientName: request.recipientName,
      phone: request.phone,
      addressLine: request.addressLine,
      barangay: request.barangay,
      city: request.city,
      province: request.province,
      postalCode: request.postalCode,
      latitude: request.latitude,
      longitude: request.longitude,
      notes: request.notes,
      isDefault: request.isDefault,
    );
    addresses = [
      for (final address in addresses)
        if (address.id == id)
          updated
        else
          CustomerAddress(
            id: address.id,
            label: address.label,
            recipientName: address.recipientName,
            phone: address.phone,
            addressLine: address.addressLine,
            barangay: address.barangay,
            city: address.city,
            province: address.province,
            postalCode: address.postalCode,
            latitude: address.latitude,
            longitude: address.longitude,
            notes: address.notes,
            isDefault: request.isDefault ? false : address.isDefault,
          ),
    ];
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    addresses = addresses.where((address) => address.id != id).toList();
  }
}

const fakeProduct = ProductData(
  id: 11,
  storeId: 3,
  name: 'API Product',
  description: 'Loaded from the catalog repository.',
  price: 125,
  stock: 10,
  available: true,
);

const fakeStore = StoreData(
  id: 3,
  name: 'API Store',
  status: 'ACTIVE',
  description: 'Loaded from Laravel.',
  address: 'Cabanatuan City',
  products: [fakeProduct],
);

class FakeCustomerCatalogRepository implements CustomerCatalogRepository {
  final List<String?> storeSearches = [];

  @override
  Future<StoreData> getStore(int id) async => fakeStore;

  @override
  Future<List<ProductData>> listProducts({
    int? storeId,
    int? categoryId,
    String? search,
  }) async => const [fakeProduct];

  @override
  Future<List<StoreData>> listStores({String? search}) async {
    storeSearches.add(search);
    final query = search?.trim().toLowerCase() ?? '';
    if (query.isNotEmpty &&
        !fakeStore.name.toLowerCase().contains(query) &&
        !(fakeStore.description?.toLowerCase().contains(query) ?? false)) {
      return const [];
    }
    return const [fakeStore];
  }
}

class FakeCustomerOrderRepository implements CustomerOrderRepository {
  final List<CustomerOrder> orders = [];

  @override
  Future<CustomerOrder> create({
    required StoreData store,
    required List<CustomerCartLine> lines,
    required CustomerAddress address,
    String? notes,
  }) async {
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.subtotal);
    final order = CustomerOrder(
      id: 21,
      orderNumber: 'TLD-TEST-001',
      status: 'PENDING',
      statusLabel: 'Pending',
      paymentMethod: 'COD',
      subtotal: subtotal,
      deliveryFee: 49,
      discount: 0,
      total: subtotal + 49,
      deliveryAddress: address.formatted,
      createdAt: DateTime(2026, 9, 16),
      store: store,
      items: lines
          .map(
            (line) => CustomerOrderItem(
              id: line.product.id,
              productId: line.product.id,
              name: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.price,
              subtotal: line.subtotal,
            ),
          )
          .toList(),
    );
    orders.add(order);
    return order;
  }

  @override
  Future<CustomerOrder> get(int id) async => orders.firstWhere(
    (order) => order.id == id,
    orElse: () => throw StateError('Order not found'),
  );

  @override
  Future<List<CustomerOrder>> list() async => List.unmodifiable(orders);

  @override
  Future<CustomerOrder> cancel(int id, {String? reason}) async => get(id);
}

class FakeCustomerNotificationRepository
    implements CustomerNotificationRepository {
  @override
  Future<List<CustomerNotification>> list() async => const [];

  @override
  Future<CustomerNotification> markRead(int id) async =>
      throw StateError('Notification not found');
}

CustomerAppDependencies fakeCustomerDependencies({
  FakeCustomerAuthRepository? auth,
  FakeCustomerAddressRepository? addresses,
  FakeCustomerCatalogRepository? catalog,
}) => CustomerAppDependencies(
  auth ?? FakeCustomerAuthRepository(),
  addresses ?? FakeCustomerAddressRepository(),
  catalog ?? FakeCustomerCatalogRepository(),
  FakeCustomerOrderRepository(),
  FakeCustomerNotificationRepository(),
  CustomerCartController(),
);
