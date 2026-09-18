<?php

namespace Tests\Feature;

use App\Enums\DeliveryStatus;
use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Enums\UserStatus;
use App\Events\DeliveryUpdated;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\Store;
use App\Models\StoreUser;
use App\Models\User;
use App\Services\DeliveryService;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Support\Facades\Event;

class DeliveryUpdatedTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_delivery_updated_broadcasts_to_the_assigned_riders_private_channel(): void
    {
        $rider = $this->makeActiveRider();
        $delivery = Delivery::factory()->create([
            'rider_id' => $rider->id,
            'status' => DeliveryStatus::Assigned,
        ]);

        $event = new DeliveryUpdated($delivery);

        $this->assertEquals([new PrivateChannel('user.'.$rider->id)], $event->broadcastOn());
        $this->assertSame('delivery.updated', $event->broadcastAs());
        $this->assertSame($delivery->id, $event->broadcastWith()['id']);
        $this->assertSame($delivery->status->value, $event->broadcastWith()['status']);
        $this->assertSame($rider->id, $event->broadcastWith()['rider_id']);
    }

    public function test_delivery_updated_has_no_channels_when_no_rider_is_assigned(): void
    {
        $delivery = Delivery::factory()->create([
            'rider_id' => null,
            'status' => DeliveryStatus::Unassigned,
        ]);

        $this->assertSame([], (new DeliveryUpdated($delivery))->broadcastOn());
    }

    public function test_delivery_updated_is_dispatched_on_delivery_transitions(): void
    {
        Event::fake([DeliveryUpdated::class]);

        $rider = $this->makeActiveRider();
        $rider->rider()->update(['status' => RiderStatus::Online]);

        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);

        $store = Store::factory()->create();
        $storeAdmin = User::factory()->create(['role' => Role::StoreAdmin->value]);
        $storeAdmin->assignRole(Role::StoreAdmin->value);
        StoreUser::create(['store_id' => $store->id, 'user_id' => $storeAdmin->id, 'role' => 'store_admin']);

        $order = Order::factory()->create([
            'customer_id' => $customer->id,
            'store_id' => $store->id,
            'status' => 'CONFIRMED',
        ]);

        $delivery = Delivery::factory()->create([
            'order_id' => $order->id,
            'store_id' => $store->id,
            'rider_id' => $rider->id,
            'status' => DeliveryStatus::Assigned,
        ]);

        $service = app(DeliveryService::class);

        $service->arrived($delivery, $rider);
        Event::assertDispatched(
            fn (DeliveryUpdated $event) => $event->delivery->status === DeliveryStatus::Accepted,
        );

        Event::fake([DeliveryUpdated::class]);
        $service->pickup($delivery->fresh(), $rider);
        Event::assertDispatched(
            fn (DeliveryUpdated $event) => $event->delivery->status === DeliveryStatus::PickedUp,
        );

        Event::fake([DeliveryUpdated::class]);
        $service->start($delivery->fresh(), $rider);
        Event::assertDispatched(
            fn (DeliveryUpdated $event) => $event->delivery->status === DeliveryStatus::InTransit,
        );

        Event::fake([DeliveryUpdated::class]);
        $service->complete($delivery->fresh(), $rider);
        Event::assertDispatched(
            fn (DeliveryUpdated $event) => $event->delivery->status === DeliveryStatus::Delivered,
        );
    }

    public function test_delivery_updated_is_dispatched_when_admin_assigns_a_rider(): void
    {
        Event::fake([DeliveryUpdated::class]);

        $rider = User::factory()->create([
            'role' => Role::Rider->value,
            'status' => UserStatus::Active,
        ]);
        $rider->assignRole(Role::Rider->value);
        $rider->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Online,
            'is_online' => true,
        ]);

        $delivery = Delivery::factory()->create(['status' => DeliveryStatus::Unassigned]);

        app(DeliveryService::class)->assign($delivery, $rider);

        Event::assertDispatched(
            fn (DeliveryUpdated $event) => $event->delivery->rider_id === $rider->id
                && $event->delivery->status === DeliveryStatus::Assigned,
        );
    }

    private function makeActiveRider(): User
    {
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

        return $rider;
    }
}
