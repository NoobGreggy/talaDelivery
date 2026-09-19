<?php

namespace Tests\Feature;

use App\Enums\DeliveryStatus;
use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Enums\UserStatus;
use App\Jobs\ExpireDeliveryOffer;
use App\Models\Delivery;
use App\Models\User;
use App\Services\RiderMatchingService;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Support\Facades\Queue;

class RiderMatchingTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_nearest_online_rider_with_coordinates_is_selected(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

        $near = $this->makeOnlineRider(14.6000, 120.9900);
        $this->makeOnlineRider(15.0000, 121.0000);

        $delivery = $this->makeDelivery(14.6001, 120.9901);

        $offer = app(RiderMatchingService::class)->match($delivery);

        $this->assertNotNull($offer);
        $this->assertSame($near->id, $offer->rider_id);
        $this->assertSame($delivery->id, $offer->delivery_id);
    }

    public function test_offer_remains_available_for_five_minutes(): void
    {
        $this->travelTo('2026-09-20 12:00:00');
        Queue::fake([ExpireDeliveryOffer::class]);

        $rider = $this->makeOnlineRider(14.60, 120.99);
        $delivery = $this->makeDelivery(14.60, 120.99);

        $offer = app(RiderMatchingService::class)->match($delivery);

        $this->assertNotNull($offer);
        $this->assertSame('2026-09-20 12:00:00', $offer->offered_at->toDateTimeString());
        $this->assertSame('2026-09-20 12:05:00', $offer->expires_at->toDateTimeString());

        Queue::assertPushed(ExpireDeliveryOffer::class, fn (ExpireDeliveryOffer $job) => $job->offer->is($offer)
            && $job->delay?->toDateTimeString() === '2026-09-20 12:05:00'
        );

        $this->assertDatabaseHas('notifications', [
            'user_id' => $rider->id,
            'type' => 'offer.new',
            'message' => 'You have a new delivery offer. You have 5 minutes to respond.',
        ]);

        $token = $rider->createToken('auth-token')->plainTextToken;

        $this->travelTo('2026-09-20 12:04:59');
        $this->withToken($token)->getJson('/api/v1/rider/offers')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->travelTo('2026-09-20 12:05:00');
        $this->withToken($token)->getJson('/api/v1/rider/offers')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->withToken($token)->postJson("/api/v1/rider/offers/{$offer->id}/accept")
            ->assertUnprocessable()
            ->assertJsonPath('message', 'This offer has expired.');
    }

    public function test_online_rider_without_coordinates_is_skipped(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

        $withCoords = $this->makeOnlineRider(14.60, 120.99);
        $withoutCoords = User::factory()->create([
            'role' => Role::Rider->value,
            'status' => UserStatus::Active,
        ]);
        $withoutCoords->assignRole(Role::Rider->value);
        $withoutCoords->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Online,
            'is_online' => true,
        ]);

        $delivery = $this->makeDelivery(14.60, 120.99);

        $offer = app(RiderMatchingService::class)->match($delivery);

        $this->assertSame($withCoords->id, $offer?->rider_id);
    }

    public function test_match_returns_null_when_no_online_rider_has_coordinates(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

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

        $delivery = $this->makeDelivery(14.60, 120.99);

        $this->assertNull(app(RiderMatchingService::class)->match($delivery));
    }

    public function test_match_returns_null_for_an_already_assigned_delivery(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

        $rider = $this->makeOnlineRider(14.60, 120.99);
        $delivery = $this->makeDelivery(14.60, 120.99);
        $delivery->update([
            'status' => DeliveryStatus::Assigned,
            'rider_id' => $rider->id,
        ]);

        $this->assertNull(app(RiderMatchingService::class)->match($delivery->fresh()));
    }

    public function test_rider_already_offered_for_a_delivery_is_not_re_selected(): void
    {
        Queue::fake([ExpireDeliveryOffer::class]);

        $first = $this->makeOnlineRider(14.6000, 120.9900);
        $second = $this->makeOnlineRider(14.6005, 120.9905);

        $delivery = $this->makeDelivery(14.6001, 120.9901);

        $firstOffer = app(RiderMatchingService::class)->match($delivery);
        $secondOffer = app(RiderMatchingService::class)->match($delivery->fresh());

        $this->assertSame($first->id, $firstOffer?->rider_id);
        $this->assertSame($second->id, $secondOffer?->rider_id);
    }

    private function makeOnlineRider(float $lat, float $lng): User
    {
        $user = User::factory()->create([
            'role' => Role::Rider->value,
            'status' => UserStatus::Active,
        ]);
        $user->assignRole(Role::Rider->value);
        $user->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => RiderStatus::Online,
            'is_online' => true,
            'current_latitude' => $lat,
            'current_longitude' => $lng,
        ]);

        return $user;
    }

    private function makeDelivery(float $lat, float $lng): Delivery
    {
        return Delivery::factory()->create([
            'pickup_latitude' => $lat,
            'pickup_longitude' => $lng,
        ]);
    }
}
