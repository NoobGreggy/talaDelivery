// Stable keys match Flutter's built-in Material Icons (no uploaded font/codepoints).
export const CATEGORY_ICONS = [
  { key: 'restaurant_rounded', label: 'Food / Restaurant' },
  { key: 'local_grocery_store_rounded', label: 'Groceries / Market' },
  { key: 'medication_rounded', label: 'Pharmacy / Health' },
  { key: 'inventory_2_rounded', label: 'Parcel / Delivery' },
  { key: 'local_offer_rounded', label: 'Deals / Promotions' },
  { key: 'grid_view_rounded', label: 'General' },
] as const;

export const CATEGORY_ICON_KEYS = CATEGORY_ICONS.map((icon) => icon.key);
