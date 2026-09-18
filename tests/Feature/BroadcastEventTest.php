<?php

namespace Tests\Feature;

use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Events\DeliveryOffered;
use App\Events\NotificationCreated;
use App\Events\OrderUpdated;
use App\Jobs\ExpireDeliveryOffer;
use App\Models\Category;
use App\Models\DeliveryZone;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreUser;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;

class BroadcastEventTest extends ApiTestCase
{
    private Store $store;

    private Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);

        DeliveryZone::factory()->create([
            'city' => 'Manila',
            'province' => 'Metro Manila',
        ]);

        $this->store = Store::factory()->create([
            'latitude' => 14.5995,
            'longitude' => 120.9842,
        ]);

        $category = Category::factory()->create(['store_id' => $this->store->id]);

        $this->product = Product::factory()->create([
            'store_id' => $this->store->id,
            'category_id' => $category->id,
            'price' => 100,
            'stock' => 10,
        ]);
    }

    public function test_notification_created_event_is_dispatched_on_order_create(): void
    {
        Event::fake([
            NotificationCreated::class,
            OrderUpdated::class,
        ]);
        Queue::fake([ExpireDeliveryOffer::class]);

        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $customerToken = $customer->createToken('auth-token')->plainTextToken;

        $storeAdmin = User::factory()->create(['role' => Role::StoreAdmin->value]);
        $storeAdmin->assignRole(Role::StoreAdmin->value);
        StoreUser::create([
            'store_id' => $this->store->id,
            'user_id' => $storeAdmin->id,
            'role' => 'store_admin',
        ]);

        $this->withToken($customerToken)->postJson('/api/v1/orders', [
            'store_id' => $this->store->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1],
            ],
            'delivery_address' => '123 Rizal Ave',
            'delivery_latitude' => 14.60,
            'delivery_longitude' => 120.99,
            'city' => 'Manila',
            'province' => 'Metro Manila',
        ])->assertCreated();

        Event::assertDispatched(NotificationCreated::class);
        Event::assertDispatched(OrderUpdated::class);
    }

    public function test_notification_created_is_dispatched_on_order_confirm(): void
    {
        Event::fake([NotificationCreated::class, OrderUpdated::class]);
        Queue::fake([ExpireDeliveryOffer::class]);

        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $customerToken = $customer->createToken('auth-token')->plainTextToken;

        $storeAdmin = User::factory()->create(['role' => Role::StoreAdmin->value]);
        $storeAdmin->assignRole(Role::StoreAdmin->value);
        StoreUser::create([
            'store_id' => $this->store->id,
            'user_id' => $storeAdmin->id,
            'role' => 'store_admin',
        ]);
        $storeAdminToken = $storeAdmin->createToken('auth-token')->plainTextToken;

        $order = $this->withToken($customerToken)->postJson('/api/v1/orders', [
            'store_id' => $this->store->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1],
            ],
            'delivery_address' => '123 Rizal Ave',
            'delivery_latitude' => 14.60,
            'delivery_longitude' => 120.99,
            'city' => 'Manila',
            'province' => 'Metro Manila',
        ])->assertCreated()->json('data');

        Event::fake([NotificationCreated::class, OrderUpdated::class]);

        $storeHeaders = ['X-Store-Id' => (string) $this->store->id];

        auth()->forgetGuards();

        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/confirm")
            ->assertOk();

        Event::assertDispatched(NotificationCreated::class);
        Event::assertDispatched(OrderUpdated::class);
    }

    public function test_delivery_offered_event_is_dispatched_on_rider_match(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);
        Event::fake([NotificationCreated::class, DeliveryOffered::class, OrderUpdated::class]);

        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $customerToken = $customer->createToken('auth-token')->plainTextToken;

        $storeAdmin = User::factory()->create(['role' => Role::StoreAdmin->value]);
        $storeAdmin->assignRole(Role::StoreAdmin->value);
        StoreUser::create([
            'store_id' => $this->store->id,
            'user_id' => $storeAdmin->id,
            'role' => 'store_admin',
        ]);
        $storeAdminToken = $storeAdmin->createToken('auth-token')->plainTextToken;

        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Online,
            'is_online' => true,
            'current_latitude' => 14.60,
            'current_longitude' => 120.99,
        ]);

        $order = $this->withToken($customerToken)->postJson('/api/v1/orders', [
            'store_id' => $this->store->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1],
            ],
            'delivery_address' => '123 Rizal Ave',
            'delivery_latitude' => 14.60,
            'delivery_longitude' => 120.99,
            'city' => 'Manila',
            'province' => 'Metro Manila',
        ])->assertCreated()->json('data');

        Event::fake([NotificationCreated::class, DeliveryOffered::class, OrderUpdated::class]);

        $storeHeaders = ['X-Store-Id' => (string) $this->store->id];

        auth()->forgetGuards();

        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/confirm")->assertOk();
        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/preparing")->assertOk();

        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/ready")
            ->assertOk();

        Event::assertDispatched(DeliveryOffered::class);
        Event::assertDispatched(NotificationCreated::class);
    }
}
