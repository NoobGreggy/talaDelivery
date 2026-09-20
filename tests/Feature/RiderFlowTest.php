<?php

namespace Tests\Feature;

use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Jobs\ExpireDeliveryOffer;
use App\Models\Category;
use App\Models\Delivery;
use App\Models\DeliveryZone;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreUser;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Support\Facades\Queue;
use Illuminate\Testing\TestResponse;

class RiderFlowTest extends ApiTestCase
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

    public function test_rider_receives_offer_and_can_complete_the_full_delivery(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

        [$customerToken, $storeAdminToken] = $this->createParticipants();

        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $rider = $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Online,
            'is_online' => true,
            'current_latitude' => 14.60,
            'current_longitude' => 120.99,
        ]);
        $riderToken = $riderUser->createToken('auth-token')->plainTextToken;

        $order = $this->withToken($customerToken)->postJson('/api/v1/orders', $this->orderPayload())
            ->assertCreated()
            ->json('data');

        $storeHeaders = ['X-Store-Id' => (string) $this->store->id];

        auth()->forgetGuards();

        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/confirm")->assertOk();
        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/preparing")->assertOk();

        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/ready")
            ->assertOk()
            ->assertJsonPath('data.status', 'READY_FOR_PICKUP');

        Queue::assertPushed(ExpireDeliveryOffer::class);

        auth()->forgetGuards();

        $offer = $this->withToken($riderToken)->getJson('/api/v1/rider/offers')
            ->assertOk()
            ->assertJsonPath('data.0.delivery.id', $order['delivery']['id'])
            ->json('data.0');

        $deliveryId = $order['delivery']['id'];

        $this->withToken($riderToken)
            ->postJson("/api/v1/rider/offers/{$offer['id']}/accept")
            ->assertOk()
            ->assertJsonPath('data.delivery.id', $deliveryId);

        $this->assertDatabaseHas('deliveries', ['id' => $deliveryId, 'status' => 'ASSIGNED']);
        $this->assertDatabaseHas('orders', ['id' => $order['id'], 'status' => 'RIDER_ASSIGNED']);

        $this->postRider($riderToken, "/api/v1/rider/deliveries/{$deliveryId}/arrived")
            ->assertOk()
            ->assertJsonPath('data.status', 'ACCEPTED');

        $this->postRider($riderToken, "/api/v1/rider/deliveries/{$deliveryId}/pickup")
            ->assertOk()
            ->assertJsonPath('data.status', 'PICKED_UP');
        $this->assertDatabaseHas('orders', ['id' => $order['id'], 'status' => 'PICKED_UP']);

        $this->postRider($riderToken, "/api/v1/rider/deliveries/{$deliveryId}/start")
            ->assertOk()
            ->assertJsonPath('data.status', 'IN_TRANSIT');
        $this->assertDatabaseHas('orders', ['id' => $order['id'], 'status' => 'OUT_FOR_DELIVERY']);

        $this->postRider($riderToken, "/api/v1/rider/deliveries/{$deliveryId}/complete")
            ->assertOk()
            ->assertJsonPath('data.status', 'DELIVERED');
        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'status' => 'DELIVERED',
            'payment_status' => 'PAID',
        ]);

        $this->assertSame(RiderStatus::Online, $rider->fresh()->status);
    }

    public function test_rider_going_online_receives_an_offer_for_an_already_ready_order(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

        [$customerToken, $storeAdminToken] = $this->createParticipants();
        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Offline,
            'is_online' => false,
            'current_latitude' => 14.60,
            'current_longitude' => 120.99,
        ]);
        $riderToken = $riderUser->createToken('auth-token')->plainTextToken;

        $order = $this->withToken($customerToken)->postJson('/api/v1/orders', $this->orderPayload())
            ->assertCreated()
            ->json('data');
        $storeHeaders = ['X-Store-Id' => (string) $this->store->id];
        auth()->forgetGuards();
        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/confirm")->assertOk();
        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/ready")->assertOk();
        $this->assertDatabaseMissing('delivery_offers', ['delivery_id' => $order['delivery']['id']]);

        auth()->forgetGuards();
        $this->withToken($riderToken)->postJson('/api/v1/rider/online')->assertOk();

        $this->withToken($riderToken)->getJson('/api/v1/rider/offers')
            ->assertOk()
            ->assertJsonPath('data.0.delivery.id', $order['delivery']['id']);
    }

    public function test_first_location_report_matches_an_already_ready_order(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

        [$customerToken, $storeAdminToken] = $this->createParticipants();
        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Offline,
            'is_online' => false,
        ]);
        $riderToken = $riderUser->createToken('auth-token')->plainTextToken;

        $order = $this->withToken($customerToken)->postJson('/api/v1/orders', $this->orderPayload())
            ->assertCreated()
            ->json('data');
        $storeHeaders = ['X-Store-Id' => (string) $this->store->id];
        auth()->forgetGuards();
        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/confirm")->assertOk();
        $this->withToken($storeAdminToken)->withHeaders($storeHeaders)
            ->postJson("/api/v1/store/orders/{$order['id']}/ready")->assertOk();

        auth()->forgetGuards();
        $this->withToken($riderToken)->postJson('/api/v1/rider/online')->assertOk();
        $this->assertDatabaseMissing('delivery_offers', ['delivery_id' => $order['delivery']['id']]);

        $this->withToken($riderToken)->postJson('/api/v1/rider/location', [
            'latitude' => 14.60,
            'longitude' => 120.99,
        ])->assertOk();

        $this->withToken($riderToken)->getJson('/api/v1/rider/offers')
            ->assertOk()
            ->assertJsonPath('data.0.delivery.id', $order['delivery']['id']);
    }

    public function test_admin_can_manually_assign_a_rider_to_a_delivery(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Online,
            'is_online' => true,
        ]);

        [$customerToken, $storeAdminToken] = $this->createParticipants();

        $order = $this->withToken($customerToken)->postJson('/api/v1/orders', $this->orderPayload())
            ->assertCreated()
            ->json('data');

        $delivery = Delivery::findOrFail($order['delivery']['id']);

        auth()->forgetGuards();

        $this->withToken($adminToken)
            ->postJson("/api/v1/admin/deliveries/{$delivery->id}/assign", ['rider_id' => $riderUser->id])
            ->assertOk()
            ->assertJsonPath('data.status', 'ASSIGNED');

        $this->assertDatabaseHas('deliveries', ['id' => $delivery->id, 'rider_id' => $riderUser->id]);
        $this->assertDatabaseHas('orders', ['id' => $order['id'], 'status' => 'RIDER_ASSIGNED']);
    }

    public function test_admin_can_cancel_a_delivery(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        [$customerToken] = $this->createParticipants();

        $order = $this->withToken($customerToken)->postJson('/api/v1/orders', $this->orderPayload())
            ->assertCreated()
            ->json('data');

        $delivery = Delivery::findOrFail($order['delivery']['id']);

        auth()->forgetGuards();

        $this->withToken($adminToken)
            ->postJson("/api/v1/admin/deliveries/{$delivery->id}/cancel", ['reason' => 'Out of stock'])
            ->assertOk()
            ->assertJsonPath('data.status', 'CANCELLED');

        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'status' => 'CANCELLED',
            'cancelled_by' => 'admin',
        ]);
    }

    /**
     * @return array{0: string, 1: string}
     */
    private function postRider(string $token, string $uri): TestResponse
    {
        return $this->withToken($token)->postJson($uri);
    }

    /**
     * @return array{0: string, 1: string}
     */
    private function createParticipants(): array
    {
        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);

        $storeAdmin = User::factory()->create(['role' => Role::StoreAdmin->value]);
        $storeAdmin->assignRole(Role::StoreAdmin->value);
        StoreUser::create([
            'store_id' => $this->store->id,
            'user_id' => $storeAdmin->id,
            'role' => 'store_admin',
        ]);

        return [
            $customer->createToken('auth-token')->plainTextToken,
            $storeAdmin->createToken('auth-token')->plainTextToken,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function orderPayload(): array
    {
        return [
            'store_id' => $this->store->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 2],
            ],
            'delivery_address' => '123 Rizal Ave',
            'delivery_latitude' => 14.60,
            'delivery_longitude' => 120.99,
            'city' => 'Manila',
            'province' => 'Metro Manila',
            'payment_method' => 'COD',
        ];
    }
}
