<?php

namespace Tests\Feature;

use App\Enums\DeliveryStatus;
use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Enums\UserStatus;
use App\Events\RiderLocationUpdated;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Support\Facades\Event;

class RiderLocationTrackingTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_active_rider_location_is_saved_and_broadcast_immediately(): void
    {
        Event::fake([RiderLocationUpdated::class]);
        [$rider, $delivery, $token] = $this->activeDelivery();

        $this->withToken($token)->postJson('/api/v1/rider/location', [
            'delivery_id' => $delivery->id,
            'latitude' => 14.5995123,
            'longitude' => 120.9842123,
            'accuracy_m' => 8.5,
            'heading_deg' => 92,
            'speed_mps' => 6.2,
            'recorded_at' => now()->toISOString(),
        ])->assertOk()
            ->assertJsonPath('data.current_latitude', '14.5995123')
            ->assertJsonPath('data.current_longitude', '120.9842123');

        $this->assertNotNull($rider->rider->fresh()->current_location_updated_at);
        Event::assertDispatched(
            RiderLocationUpdated::class,
            fn (RiderLocationUpdated $event) => $event->delivery->is($delivery)
                && $event->rider->is($rider->rider)
                && $event->accuracy === 8.5,
        );
    }

    public function test_location_event_uses_delivery_channel_and_minimal_payload(): void
    {
        [$rider, $delivery] = $this->activeDelivery();
        $profile = $rider->rider;
        $profile->update([
            'current_latitude' => 14.5995123,
            'current_longitude' => 120.9842123,
            'current_location_updated_at' => now(),
        ]);

        $event = new RiderLocationUpdated($delivery, $profile->fresh(), 8.5, 92, 6.2);
        $payload = $event->broadcastWith();

        $this->assertEquals([new PrivateChannel('delivery.'.$delivery->id)], $event->broadcastOn());
        $this->assertSame('rider.location.updated', $event->broadcastAs());
        $this->assertSame($delivery->id, $payload['delivery_id']);
        $this->assertSame($rider->id, $payload['rider_id']);
        $this->assertSame(14.5995123, $payload['latitude']);
        $this->assertSame(120.9842123, $payload['longitude']);
        $this->assertArrayNotHasKey('delivery_address', $payload);
    }

    public function test_rider_cannot_report_location_for_another_delivery(): void
    {
        [, , $token] = $this->activeDelivery();
        $otherDelivery = Delivery::factory()->create();

        $this->withToken($token)->postJson('/api/v1/rider/location', [
            'delivery_id' => $otherDelivery->id,
            'latitude' => 14.5995,
            'longitude' => 120.9842,
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'This rider is not assigned to the selected delivery.');
    }

    public function test_stale_location_is_rejected(): void
    {
        [, $delivery, $token] = $this->activeDelivery();

        $this->withToken($token)->postJson('/api/v1/rider/location', [
            'delivery_id' => $delivery->id,
            'latitude' => 14.5995,
            'longitude' => 120.9842,
            'recorded_at' => now()->subMinutes(3)->toISOString(),
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'The rider location timestamp is stale or invalid.');
    }

    /**
     * @return array{0: User, 1: Delivery, 2: string}
     */
    private function activeDelivery(): array
    {
        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $rider = User::factory()->create([
            'role' => Role::Rider->value,
            'status' => UserStatus::Active,
        ]);
        $rider->assignRole(Role::Rider->value);
        $rider->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Busy,
            'is_online' => true,
        ]);
        $order = Order::factory()->create(['customer_id' => $customer->id]);
        $delivery = Delivery::factory()->create([
            'order_id' => $order->id,
            'store_id' => $order->store_id,
            'rider_id' => $rider->id,
            'status' => DeliveryStatus::Assigned,
        ]);

        return [$rider, $delivery, $rider->createToken('auth-token')->plainTextToken];
    }
}
