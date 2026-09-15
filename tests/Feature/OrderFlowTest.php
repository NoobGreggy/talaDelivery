<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\Category;
use App\Models\DeliveryZone;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreUser;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Testing\TestResponse;

class OrderFlowTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);

        $this->zone = DeliveryZone::factory()->create([
            'city' => 'Manila',
            'province' => 'Metro Manila',
        ]);

        $this->store = Store::factory()->create([
            'latitude' => 14.5995,
            'longitude' => 120.9842,
        ]);

        $this->category = Category::factory()->create(['store_id' => $this->store->id]);

        $this->product = Product::factory()->create([
            'store_id' => $this->store->id,
            'category_id' => $this->category->id,
            'price' => 100,
            'stock' => 10,
        ]);

        $this->storeAdmin = User::factory()->create(['role' => Role::StoreAdmin->value]);
        $this->storeAdmin->assignRole(Role::StoreAdmin->value);
        StoreUser::create([
            'store_id' => $this->store->id,
            'user_id' => $this->storeAdmin->id,
            'role' => 'store_admin',
        ]);

        $this->customer = User::factory()->create(['role' => Role::Customer->value]);
        $this->customer->assignRole(Role::Customer->value);
    }

    public function test_customer_can_create_an_order(): void
    {
        $response = $this->actingAsCustomer()->postJson('/api/v1/orders', $this->orderPayload());

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'PENDING')
            ->assertJsonPath('data.delivery.status', 'UNASSIGNED')
            ->assertJsonPath('data.subtotal', '200.00')
            ->assertJsonPath('data.delivery_fee', '49.00')
            ->assertJsonPath('data.total', '249.00');

        $this->assertDatabaseHas('orders', ['order_number' => $response->json('data.order_number')]);
        $this->assertSame(8, $this->product->fresh()->stock);
    }

    public function test_store_can_confirm_prepare_and_mark_order_ready(): void
    {
        $order = $this->createOrder();

        $this->actingAsCustomer()->getJson("/api/v1/orders/{$order['id']}")
            ->assertOk()
            ->assertJsonPath('data.status', 'PENDING');

        $this->postStore("/api/v1/store/orders/{$order['id']}/confirm")
            ->assertOk()
            ->assertJsonPath('data.status', 'CONFIRMED');

        $this->postStore("/api/v1/store/orders/{$order['id']}/preparing")
            ->assertOk()
            ->assertJsonPath('data.status', 'PREPARING');

        $this->postStore("/api/v1/store/orders/{$order['id']}/ready")
            ->assertOk()
            ->assertJsonPath('data.status', 'READY_FOR_PICKUP');
    }

    public function test_customer_can_only_cancel_a_pending_order(): void
    {
        $order = $this->createOrder();

        $this->actingAsCustomer()->postJson("/api/v1/orders/{$order['id']}/cancel", ['reason' => 'Changed my mind'])
            ->assertOk()
            ->assertJsonPath('data.status', 'CANCELLED');

        $order = $this->createOrder();

        $this->postStore("/api/v1/store/orders/{$order['id']}/confirm")
            ->assertOk();

        $this->actingAsCustomer()->postJson("/api/v1/orders/{$order['id']}/cancel")
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Only pending orders can be cancelled.');
    }

    public function test_customer_can_track_their_order(): void
    {
        $order = $this->createOrder();

        $this->actingAsCustomer()->getJson("/api/v1/orders/{$order['id']}")
            ->assertOk()
            ->assertJsonPath('data.id', $order['id'])
            ->assertJsonStructure(['data' => ['delivery' => ['status'], 'items']]);
    }

    public function test_store_admin_cannot_touch_another_stores_order(): void
    {
        $otherStore = Store::factory()->create();
        $otherProduct = Product::factory()->create([
            'store_id' => $otherStore->id,
            'category_id' => Category::factory()->create(['store_id' => $otherStore->id])->id,
            'price' => 50,
            'stock' => 5,
        ]);

        $response = $this->actingAsCustomer()->postJson('/api/v1/orders', [
            'store_id' => $otherStore->id,
            'items' => [
                ['product_id' => $otherProduct->id, 'quantity' => 1],
            ],
            'delivery_address' => '123 Rizal Ave',
            'delivery_latitude' => 14.60,
            'delivery_longitude' => 120.99,
            'city' => 'Manila',
            'province' => 'Metro Manila',
            'payment_method' => 'COD',
        ]);

        $response->assertCreated();

        $this->postStore("/api/v1/store/orders/{$response->json('data.id')}/confirm")
            ->assertNotFound();
    }

    private function createOrder(): array
    {
        $response = $this->actingAsCustomer()->postJson('/api/v1/orders', $this->orderPayload());

        $response->assertCreated();

        return $response->json('data');
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

    protected function actingAsCustomer(): static
    {
        auth()->forgetGuards();

        $token = $this->customer->createToken('auth-token')->plainTextToken;

        return $this->withToken($token);
    }

    protected function postStore(string $uri): TestResponse
    {
        auth()->forgetGuards();

        $token = $this->storeAdmin->createToken('auth-token')->plainTextToken;

        return $this->withToken($token)
            ->withHeader('X-Store-Id', (string) $this->store->id)
            ->postJson($uri);
    }
}
