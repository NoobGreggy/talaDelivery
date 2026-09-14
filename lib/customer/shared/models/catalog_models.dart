part of '../../app.dart';

class StoreData {
  const StoreData(
    this.name,
    this.description,
    this.rating,
    this.fee,
    this.eta,
    this.icon,
    this.color,
    this.categoryIndex, {
    this.open = true,
  });
  final String name;
  final String description;
  final String rating;
  final int fee;
  final String eta;
  final IconData icon;
  final Color color;
  final int categoryIndex;
  final bool open;
}

const stores = [
  StoreData(
    'ABC Mini Mart',
    'Groceries, snacks, drinks, and daily essentials.',
    '4.8',
    49,
    '25–35 min',
    Icons.storefront_rounded,
    sky,
    2,
  ),
  StoreData(
    'XYZ Food House',
    'Filipino comfort food made fresh.',
    '4.7',
    49,
    '30–40 min',
    Icons.restaurant_rounded,
    Color(0xFFFF8749),
    1,
  ),
  StoreData(
    'Mercury Pharmacy',
    'Medicine and health essentials.',
    '4.9',
    59,
    '20–30 min',
    Icons.medication_rounded,
    success,
    3,
  ),
  StoreData(
    'Daily Needs',
    'Convenience items close to home.',
    '4.5',
    45,
    '25–40 min',
    Icons.shopping_basket_rounded,
    Color(0xFF7659E9),
    4,
    open: false,
  ),
];

class ProductData {
  const ProductData(
    this.name,
    this.description,
    this.price,
    this.icon,
    this.color, {
    this.available = true,
  });
  final String name;
  final String description;
  final int price;
  final IconData icon;
  final Color color;
  final bool available;
}

const products = [
  ProductData(
    'Chicken Rice Bowl',
    'Tender chicken, steamed rice, and house sauce.',
    100,
    Icons.rice_bowl_rounded,
    Color(0xFFFF8749),
  ),
  ProductData(
    'Iced Tea',
    'Freshly brewed lemon iced tea, 500 ml.',
    50,
    Icons.local_drink_rounded,
    sky,
  ),
  ProductData(
    'Family Grocery Pack',
    'A curated pack of everyday pantry essentials.',
    399,
    Icons.shopping_basket_rounded,
    success,
  ),
  ProductData(
    'Fresh Bread',
    'Soft baked bread prepared fresh today.',
    85,
    Icons.bakery_dining_rounded,
    warning,
    available: false,
  ),
];
