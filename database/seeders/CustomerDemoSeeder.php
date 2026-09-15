<?php

namespace Database\Seeders;

use App\Enums\Role;
use App\Enums\StoreStatus;
use App\Enums\UserStatus;
use App\Models\DeliveryZone;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Spatie\Permission\Models\Role as SpatieRole;

class CustomerDemoSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed a repeatable catalog for customer application testing.
     */
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            return;
        }

        if (! SpatieRole::query()->where('name', Role::Customer->value)->exists()) {
            $this->call(RolePermissionSeeder::class);
        }

        DB::transaction(function (): void {
            $this->seedCustomer();
            $this->seedDeliveryZone();
            $this->seedCatalog();
        });
    }

    private function seedCustomer(): void
    {
        $customer = User::query()->updateOrCreate(
            ['email' => 'customer@taladelivery.test'],
            [
                'name' => 'Tala Demo Customer',
                'phone' => '09171234567',
                'password' => 'password123',
                'role' => Role::Customer->value,
                'status' => UserStatus::Active->value,
            ],
        );

        $customer->syncRoles([Role::Customer->value]);

        $customer->addresses()->updateOrCreate(
            ['label' => 'Home'],
            [
                'recipient_name' => $customer->name,
                'phone' => $customer->phone,
                'address_line' => '123 Maharlika Highway',
                'barangay' => 'Kapitan Pepe',
                'city' => 'Cabanatuan City',
                'province' => 'Nueva Ecija',
                'postal_code' => '3100',
                'latitude' => 15.4865,
                'longitude' => 120.9734,
                'notes' => 'Demo address for customer application testing.',
                'is_default' => true,
            ],
        );
    }

    private function seedDeliveryZone(): void
    {
        DeliveryZone::query()->updateOrCreate(
            ['name' => 'Cabanatuan City Zone'],
            [
                'city' => 'Cabanatuan City',
                'province' => 'Nueva Ecija',
                'base_fee' => 49,
                'included_km' => 5,
                'extra_fee_per_km' => 10,
                'status' => StoreStatus::Active->value,
            ],
        );
    }

    private function seedCatalog(): void
    {
        foreach ($this->catalog() as $storeData) {
            $categories = $storeData['categories'];
            unset($storeData['categories']);

            $store = Store::query()->updateOrCreate(
                ['slug' => $storeData['slug']],
                $storeData,
            );

            foreach ($categories as $categoryData) {
                $products = $categoryData['products'];
                unset($categoryData['products']);

                $category = $store->categories()->updateOrCreate(
                    ['name' => $categoryData['name']],
                    $categoryData,
                );

                foreach ($products as $productData) {
                    $store->products()->updateOrCreate(
                        ['sku' => $productData['sku']],
                        [...$productData, 'category_id' => $category->id],
                    );
                }
            }
        }
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function catalog(): array
    {
        return [
            [
                'name' => 'Cabanatuan Food Corner',
                'slug' => 'cabanatuan-food-corner',
                'description' => 'Classic Filipino meals, merienda, and refreshing drinks.',
                'phone' => '09170000001',
                'email' => 'foodcorner@taladelivery.test',
                'address' => 'Burgos Avenue, Cabanatuan City, Nueva Ecija',
                'latitude' => 15.4859,
                'longitude' => 120.9661,
                'status' => StoreStatus::Active->value,
                'opening_time' => '08:00:00',
                'closing_time' => '21:00:00',
                'categories' => [
                    [
                        'name' => 'Rice Meals',
                        'description' => 'Filling Filipino favorites served with rice.',
                        'status' => StoreStatus::Active->value,
                        'products' => [
                            $this->product('CFC-RM-001', 'Chicken Adobo Rice', 'Tender chicken adobo with steamed rice.', 129),
                            $this->product('CFC-RM-002', 'Pork Sisig Rice', 'Sizzling-style pork sisig with steamed rice.', 139),
                            $this->product('CFC-RM-003', 'Beef Tapa Rice', 'Sweet-savory beef tapa with egg and rice.', 149),
                        ],
                    ],
                    [
                        'name' => 'Merienda and Drinks',
                        'description' => 'Local snacks and cold drinks.',
                        'status' => StoreStatus::Active->value,
                        'products' => [
                            $this->product('CFC-MD-001', 'Pancit Bihon', 'Stir-fried rice noodles with vegetables.', 99),
                            $this->product('CFC-MD-002', 'Turon Duo', 'Two crispy banana spring rolls.', 59),
                            $this->product('CFC-MD-003', 'House Iced Tea', 'Freshly brewed lemon iced tea.', 49),
                        ],
                    ],
                ],
            ],
            [
                'name' => 'Tala Fresh Market',
                'slug' => 'tala-fresh-market',
                'description' => 'Fresh produce and everyday pantry essentials.',
                'phone' => '09170000002',
                'email' => 'freshmarket@taladelivery.test',
                'address' => 'Maharlika Highway, Cabanatuan City, Nueva Ecija',
                'latitude' => 15.4921,
                'longitude' => 120.9748,
                'status' => StoreStatus::Active->value,
                'opening_time' => '07:00:00',
                'closing_time' => '20:00:00',
                'categories' => [
                    [
                        'name' => 'Fresh Produce',
                        'description' => 'Fruits and vegetables sold by pack.',
                        'status' => StoreStatus::Active->value,
                        'products' => [
                            $this->product('TFM-FP-001', 'Lakatan Bananas', 'One kilogram of ripe Lakatan bananas.', 95),
                            $this->product('TFM-FP-002', 'Fresh Tomatoes', 'One kilogram of locally sourced tomatoes.', 110),
                            $this->product('TFM-FP-003', 'White Potatoes', 'One kilogram of all-purpose potatoes.', 125),
                        ],
                    ],
                    [
                        'name' => 'Pantry Essentials',
                        'description' => 'Kitchen staples for the household.',
                        'status' => StoreStatus::Active->value,
                        'products' => [
                            $this->product('TFM-PE-001', 'Premium Rice 5kg', 'Five kilograms of premium white rice.', 310),
                            $this->product('TFM-PE-002', 'Large Eggs Dozen', 'Twelve fresh large chicken eggs.', 125),
                            $this->product('TFM-PE-003', 'Cooking Oil 1L', 'One liter of vegetable cooking oil.', 115),
                        ],
                    ],
                ],
            ],
            [
                'name' => 'CarePlus Pharmacy',
                'slug' => 'careplus-pharmacy',
                'description' => 'Daily wellness and personal care essentials.',
                'phone' => '09170000003',
                'email' => 'careplus@taladelivery.test',
                'address' => 'General Tinio Street, Cabanatuan City, Nueva Ecija',
                'latitude' => 15.4808,
                'longitude' => 120.9689,
                'status' => StoreStatus::Active->value,
                'opening_time' => '08:00:00',
                'closing_time' => '22:00:00',
                'categories' => [
                    [
                        'name' => 'Wellness',
                        'description' => 'Non-prescription wellness supplies.',
                        'status' => StoreStatus::Active->value,
                        'products' => [
                            $this->product('CPP-WE-001', 'Vitamin C 30 Tablets', 'Daily vitamin C supplement.', 185),
                            $this->product('CPP-WE-002', 'Alcohol 500ml', 'Seventy percent isopropyl alcohol.', 89),
                            $this->product('CPP-WE-003', 'Face Masks 10 Pack', 'Ten disposable protective face masks.', 75),
                        ],
                    ],
                    [
                        'name' => 'Personal Care',
                        'description' => 'Everyday hygiene essentials.',
                        'status' => StoreStatus::Active->value,
                        'products' => [
                            $this->product('CPP-PC-001', 'Bath Soap 3 Pack', 'Three moisturizing bath soap bars.', 105),
                            $this->product('CPP-PC-002', 'Toothpaste 150ml', 'Fresh mint fluoride toothpaste.', 99),
                            $this->product('CPP-PC-003', 'Shampoo 340ml', 'Gentle everyday shampoo.', 189),
                        ],
                    ],
                ],
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function product(string $sku, string $name, string $description, float $price): array
    {
        return [
            'sku' => $sku,
            'name' => $name,
            'description' => $description,
            'price' => $price,
            'image' => null,
            'stock' => 50,
            'is_available' => true,
        ];
    }
}
