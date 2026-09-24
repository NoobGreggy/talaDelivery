<?php

namespace Tests\Feature;

use App\Enums\DeliveryStatus;
use App\Enums\Role;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;

class BroadcastAuthTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // phpunit forces BROADCAST_CONNECTION=null, which registers channels on
        // a no-op broadcaster at boot. Route the default connection through
        // Reverb/Pusher broadcaster (signs locally, no network) and reload the
        // real channel authorizers against it so auth decisions are exercised.
        config(['broadcasting.default' => 'reverb']);
        require base_path('routes/channels.php');
    }

    public function test_broadcast_auth_requires_authentication(): void
    {
        $this->postJson('/broadcasting/auth', [
            'socket_id' => '111111.222222',
            'channel_name' => 'private-user.1',
        ])->assertUnauthorized();
    }

    public function test_rider_can_authorize_their_own_private_channel(): void
    {
        $this->seed(RolePermissionSeeder::class);

        $rider = User::factory()->create(['role' => Role::Rider->value]);
        $rider->assignRole(Role::Rider->value);
        $token = $rider->createToken('auth-token')->plainTextToken;

        $this->withToken($token)
            ->postJson('/broadcasting/auth', [
                'socket_id' => '111111.222222',
                'channel_name' => 'private-user.'.$rider->id,
            ])
            ->assertOk()
            ->assertJsonStructure(['auth']);
    }

    public function test_rider_cannot_authorize_another_users_channel(): void
    {
        $this->seed(RolePermissionSeeder::class);

        $rider = User::factory()->create(['role' => Role::Rider->value]);
        $rider->assignRole(Role::Rider->value);
        $other = User::factory()->create(['role' => Role::Rider->value]);
        $other->assignRole(Role::Rider->value);

        $token = $rider->createToken('auth-token')->plainTextToken;

        $this->withToken($token)
            ->postJson('/broadcasting/auth', [
                'socket_id' => '111111.222222',
                'channel_name' => 'private-user.'.$other->id,
            ])
            ->assertForbidden();
    }

    public function test_customer_and_assigned_rider_can_authorize_delivery_channel(): void
    {
        $this->seed(RolePermissionSeeder::class);

        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $rider = User::factory()->create(['role' => Role::Rider->value]);
        $rider->assignRole(Role::Rider->value);
        $order = Order::factory()->create(['customer_id' => $customer->id]);
        $delivery = Delivery::factory()->create([
            'order_id' => $order->id,
            'store_id' => $order->store_id,
            'rider_id' => $rider->id,
            'status' => DeliveryStatus::Assigned,
        ]);

        foreach ([$customer, $rider] as $participant) {
            auth()->forgetGuards();
            $token = $participant->createToken('auth-token')->plainTextToken;
            $this->withToken($token)
                ->postJson('/broadcasting/auth', [
                    'socket_id' => '111111.222222',
                    'channel_name' => 'private-delivery.'.$delivery->id,
                ])
                ->assertOk()
                ->assertJsonStructure(['auth']);
        }
    }

    public function test_unrelated_user_cannot_authorize_delivery_channel(): void
    {
        $this->seed(RolePermissionSeeder::class);

        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $otherCustomer = User::factory()->create(['role' => Role::Customer->value]);
        $otherCustomer->assignRole(Role::Customer->value);
        $order = Order::factory()->create(['customer_id' => $customer->id]);
        $delivery = Delivery::factory()->create([
            'order_id' => $order->id,
            'store_id' => $order->store_id,
        ]);

        $token = $otherCustomer->createToken('auth-token')->plainTextToken;

        $this->withToken($token)
            ->postJson('/broadcasting/auth', [
                'socket_id' => '111111.222222',
                'channel_name' => 'private-delivery.'.$delivery->id,
            ])
            ->assertForbidden();
    }

    public function test_customer_cannot_authorize_a_completed_delivery_channel(): void
    {
        $this->seed(RolePermissionSeeder::class);

        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $order = Order::factory()->create(['customer_id' => $customer->id]);
        $delivery = Delivery::factory()->create([
            'order_id' => $order->id,
            'store_id' => $order->store_id,
            'status' => DeliveryStatus::Delivered,
        ]);
        $token = $customer->createToken('auth-token')->plainTextToken;

        $this->withToken($token)
            ->postJson('/broadcasting/auth', [
                'socket_id' => '111111.222222',
                'channel_name' => 'private-delivery.'.$delivery->id,
            ])
            ->assertForbidden();
    }
}
