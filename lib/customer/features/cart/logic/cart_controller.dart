part of '../../../app.dart';

class CustomerCartLine {
  const CustomerCartLine({required this.product, required this.quantity});

  final ProductData product;
  final int quantity;

  CustomerCartLine copyWith({int? quantity}) =>
      CustomerCartLine(product: product, quantity: quantity ?? this.quantity);

  double get subtotal => product.price * quantity;
}

class CustomerCartController extends ChangeNotifier {
  StoreData? _store;
  final Map<int, CustomerCartLine> _lines = {};

  StoreData? get store => _store;
  List<CustomerCartLine> get lines => List.unmodifiable(_lines.values);
  int get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  double get subtotal =>
      _lines.values.fold(0, (sum, line) => sum + line.subtotal);
  bool get isEmpty => _lines.isEmpty;

  bool canAddFrom(StoreData store) => _store == null || _store!.id == store.id;

  void add(StoreData store, ProductData product, {int quantity = 1}) {
    if (!canAddFrom(store)) {
      throw StateError('Cart items must come from one store.');
    }
    _store = store;
    final existing = _lines[product.id];
    final next = (existing?.quantity ?? 0) + quantity;
    _lines[product.id] = CustomerCartLine(
      product: product,
      quantity: next.clamp(1, product.stock),
    );
    notifyListeners();
  }

  void setQuantity(int productId, int quantity) {
    final existing = _lines[productId];
    if (existing == null) return;
    if (quantity <= 0) {
      _lines.remove(productId);
    } else {
      _lines[productId] = existing.copyWith(
        quantity: quantity.clamp(1, existing.product.stock),
      );
    }
    if (_lines.isEmpty) _store = null;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _store = null;
    notifyListeners();
  }
}
