<?php

namespace Database\Seeders;

use App\Enums\Role;
use App\Enums\StoreStatus;
use App\Enums\UserStatus;
use App\Models\Store;
use App\Models\StoreUser;
use App\Models\User;
use App\Services\OrderService;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Spatie\Permission\Models\Role as SpatieRole;

class MerchantDemoSeeder extends Seeder
{
    use WithoutModelEvents;

    private const STORE_SLUG = 'cabanatuan-food-corner';

    private Store $store;

    private User $merchant;

    /**
     * Seed a store-admin login and sample orders dispatched through the order
     * service so the WebSocket broadcasts fire (merchant list updates live).
     */
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            return;
        }

        if (! SpatieRole::query()->where('name', Role::StoreAdmin->value)->exists()) {
            $this->call(RolePermissionSeeder::class);
        }

        DB::transaction(function (): void {
            $this->seedMerchant();
            $this->seedOrders();
        });
    }

    private function seedMerchant(): void
    {
        $this->store = Store::query()->firstOrNew(['slug' => self::STORE_SLUG]);

        if (! $this->store->exists) {
            $this->store->fill([
                'name' => 'Cabanatuan Food Corner',
                'description' => 'Classic Filipino meals, merienda, and refreshing drinks.',
                'phone' => '09170000001',
                'email' => 'foodcorner@taladelivery.test',
                'address' => 'Burgos Avenue, Cabanatuan City, Nueva Ecija',
                'latitude' => 15.4859,
                'longitude' => 120.9661,
                'status' => StoreStatus::Active->value,
                'opening_time' => '08:00:00',
                'closing_time' => '21:00:00',
            ])->save();
        }

        $this->merchant = User::query()->updateOrCreate(
            ['email' => 'merchant@taladelivery.test'],
            [
                'name' => 'Tala Demo Merchant',
                'phone' => '09171234888',
                'password' => 'password',
                'role' => Role::StoreAdmin->value,
                'status' => UserStatus::Active->value,
            ],
        );

        $this->merchant->syncRoles([Role::StoreAdmin->value]);

        StoreUser::query()->updateOrCreate(
            ['store_id' => $this->store->id, 'user_id' => $this->merchant->id],
            ['role' => 'store_admin'],
        );
    }

    /**
     * Create PENDING demo orders through OrderService so OrderUpdated::dispatch
     * broadcasts to the merchant's store channel. Then advance dispatched
     * statuses through the service too, each step re-broadcasting live.
     */
    private function seedOrders(): void
    {
        $products = $this->store->products()->get();

        if ($products->isEmpty()) {
            return;
        }

        $customers = $this->seedCustomers();
        $orderService = app(OrderService::class);

        $specs = [
            ['status' => 'PENDING', 'minutes_ago' => 8],
            ['status' => 'PENDING', 'minutes_ago' => 4],
            ['status' => 'CONFIRMED', 'minutes_ago' => 30],
            ['status' => 'PREPARING', 'minutes_ago' => 45],
            ['status' => 'READY_FOR_PICKUP', 'minutes_ago' => 60],
            ['status' => 'DELIVERED', 'minutes_ago' => 400],
            ['status' => 'CANCELLED', 'minutes_ago' => 200],
        ];

        foreach ($specs as $index => $spec) {
            $customer = $customers[$index % count($customers)];
            $itemCount = rand(1, 3);
            $items = $products->random($itemCount)
                ->map(fn ($product) => ['product_id' => $product->id, 'quantity' => rand(1, 3)])
                ->values()
                ->all();

            $order = $orderService->create([
                'store_id' => $this->store->id,
                'items' => $items,
                'delivery_latitude' => $customer['latitude'],
                'delivery_longitude' => $customer['longitude'],
                'delivery_address' => $customer['address'],
                'city' => 'Cabanatuan City',
                'province' => 'Nueva Ecija',
                'payment_method' => 'COD',
            ], $customer['user']);

            $order->update([
                'created_at' => now()->subMinutes($spec['minutes_ago']),
                'updated_at' => now()->subMinutes($spec['minutes_ago']),
            ]);

            switch ($spec['status']) {
                case 'CONFIRMED':
                    $orderService->confirm($order);
                    break;
                case 'PREPARING':
                    $orderService->confirm($order);
                    $orderService->preparing($order);
                    break;
                case 'READY_FOR_PICKUP':
                    $orderService->confirm($order);
                    $orderService->preparing($order);
                    $orderService->ready($order);
                    break;
                case 'DELIVERED':
                    $orderService->confirm($order);
                    $orderService->preparing($order);
                    $orderService->ready($order);
                    $order->update([
                        'status' => 'DELIVERED',
                        'delivered_at' => now()->subMinutes($spec['minutes_ago'] - 70),
                    ]);
                    $order->delivery()->update([
                        'status' => 'DELIVERED',
                        'delivered_at' => now()->subMinutes($spec['minutes_ago'] - 70),
                    ]);
                    break;
                case 'CANCELLED':
                    $orderService->cancel($order, 'customer', 'Customer requested cancellation');
                    break;
                default:
                    break;
            }
        }
    }

    /**
     * @return array<int, array{user: User, name: string, phone: string, address: string, latitude: float, longitude: float}>
     */
    private function seedCustomers(): array
    {
        $customers = User::query()
            ->role(Role::Customer->value)
            ->where('status', UserStatus::Active->value)
            ->with('addresses')
            ->take(3)
            ->get();

        $records = [];

        foreach ($customers as $index => $customer) {
            $address = $customer->addresses->first();

            $records[] = [
                'user' => $customer,
                'name' => $customer->name,
                'phone' => $customer->phone,
                'address' => $address?->address_line ?? '123 Demo Street',
                'latitude' => $address?->latitude ?? 15.4865 + ($index * 0.001),
                'longitude' => $address?->longitude ?? 120.9734,
            ];
        }

        return $records;
    }
}
