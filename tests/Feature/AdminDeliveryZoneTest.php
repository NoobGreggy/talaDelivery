<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\DeliveryZone;
use App\Models\PlatformSetting;
use App\Models\User;
use App\Services\PricingService;
use Database\Seeders\RolePermissionSeeder;

class AdminDeliveryZoneTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_admin_can_create_list_update_and_archive_delivery_zones(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        $created = $this->withToken($adminToken)
            ->postJson('/api/v1/admin/delivery-zones', [
                'name' => 'Cebu Zone',
                'city' => 'Cebu City',
                'province' => 'Cebu',
                'base_fee' => 60,
                'included_km' => 3,
                'extra_fee_per_km' => 15,
            ])
            ->assertCreated()
            ->assertJsonPath('data.province', 'Cebu')
            ->assertJsonPath('data.base_fee', '60.00');

        $zoneId = $created->json('data.id');

        $this->withToken($adminToken)
            ->getJson('/api/v1/admin/delivery-zones')
            ->assertOk()
            ->assertJsonPath('data.data.0.id', $zoneId);

        $this->withToken($adminToken)
            ->getJson("/api/v1/admin/delivery-zones/{$zoneId}")
            ->assertOk()
            ->assertJsonPath('data.base_fee', '60.00');

        $this->withToken($adminToken)
            ->putJson("/api/v1/admin/delivery-zones/{$zoneId}", [
                'base_fee' => 75,
                'status' => 'INACTIVE',
            ])
            ->assertOk()
            ->assertJsonPath('data.base_fee', '75.00')
            ->assertJsonPath('data.status', 'ARCHIVED');

        $this->withToken($adminToken)
            ->deleteJson("/api/v1/admin/delivery-zones/{$zoneId}")
            ->assertOk();

        $this->assertDatabaseHas('delivery_zones', [
            'id' => $zoneId,
            'status' => 'ARCHIVED',
        ]);
        $this->assertDatabaseHas('delivery_zone_revisions', [
            'delivery_zone_id' => $zoneId,
            'action' => 'ARCHIVED',
        ]);
    }

    public function test_admin_created_zone_is_used_by_pricing(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        $this->withToken($adminToken)
            ->postJson('/api/v1/admin/delivery-zones', [
                'name' => 'Bulacan Zone',
                'city' => 'Malolos',
                'province' => 'Bulacan',
                'base_fee' => 80,
                'included_km' => 10,
                'extra_fee_per_km' => 20,
            ])
            ->assertCreated();

        $zone = DeliveryZone::where('province', 'Bulacan')->firstOrFail();

        $this->assertSame('80.00', (string) $zone->base_fee);
        $this->assertSame('10.00', (string) $zone->included_km);
        $this->assertSame('20.00', (string) $zone->extra_fee_per_km);

        $pricing = app(PricingService::class)->calculate(
            14.8433,
            120.8114,
            14.8433,
            120.8114,
            '  MALOLOS ',
            'Bulacan',
        );

        $this->assertSame($zone->id, $pricing['zone']->id);
        $this->assertSame(80.0, $pricing['delivery_fee']);
    }

    public function test_admin_cannot_activate_two_zones_for_the_same_city(): void
    {
        DeliveryZone::factory()->create([
            'city' => 'Cabanatuan City',
            'province' => 'Nueva Ecija',
            'status' => 'ACTIVE',
        ]);
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);

        $this->withToken($admin->createToken('auth-token')->plainTextToken)
            ->postJson('/api/v1/admin/delivery-zones', [
                'name' => 'Duplicate City Zone',
                'city' => '  cabanatuan   city ',
                'province' => 'Nueva Ecija',
                'base_fee' => 50,
                'included_km' => 5,
                'extra_fee_per_km' => 10,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('city');
    }

    public function test_admin_cannot_activate_overlapping_mapped_zones(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $token = $admin->createToken('auth-token')->plainTextToken;

        $firstBoundary = [
            'type' => 'Polygon',
            'coordinates' => [[[120.90, 15.40], [121.00, 15.40], [121.00, 15.50], [120.90, 15.50], [120.90, 15.40]]],
        ];
        $overlappingBoundary = [
            'type' => 'Polygon',
            'coordinates' => [[[120.95, 15.45], [121.05, 15.45], [121.05, 15.55], [120.95, 15.55], [120.95, 15.45]]],
        ];

        $this->withToken($token)
            ->postJson('/api/v1/admin/delivery-zones', $this->zonePayload('Central', $firstBoundary))
            ->assertCreated();

        $this->withToken($token)
            ->postJson('/api/v1/admin/delivery-zones', $this->zonePayload('North', $overlappingBoundary))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('boundary_geojson');
    }

    public function test_admin_can_preview_zone_coverage_pricing_and_rider_commission(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $token = $admin->createToken('auth-token')->plainTextToken;
        PlatformSetting::current()->update([
            'rider_commission_type' => 'PERCENTAGE',
            'rider_commission_value' => 20,
        ]);

        $boundary = [
            'type' => 'Polygon',
            'coordinates' => [[[119.90, 14.90], [120.10, 14.90], [120.10, 15.10], [119.90, 15.10], [119.90, 14.90]]],
        ];
        $zone = $this->zonePayload('Preview', $boundary);
        $zone['base_fee'] = 50;
        $zone['included_km'] = 0;
        $zone['extra_fee_per_km'] = 10;
        $zone['distance_rounding_km'] = 0.5;

        $this->withToken($token)
            ->postJson('/api/v1/admin/delivery-zones/preview', [
                'zone' => $zone,
                'pickup_latitude' => 15,
                'pickup_longitude' => 120,
                'delivery_latitude' => 15.004,
                'delivery_longitude' => 120,
                'distance_method' => 'STRAIGHT_LINE',
            ])
            ->assertOk()
            ->assertJsonPath('data.covered', true)
            ->assertJsonPath('data.billable_distance_km', 0.5)
            ->assertJsonPath('data.delivery_fee', 55)
            ->assertJsonPath('data.rider_commission', 11);

        $this->withToken($token)
            ->postJson('/api/v1/admin/delivery-zones/preview', [
                'zone' => $zone,
                'pickup_latitude' => 15,
                'pickup_longitude' => 120,
                'delivery_latitude' => 16,
                'delivery_longitude' => 121,
                'distance_method' => 'STRAIGHT_LINE',
            ])
            ->assertOk()
            ->assertJsonPath('data.covered', false)
            ->assertJsonPath('data.reason', 'The delivery pin is outside this zone boundary.');
    }

    public function test_non_admin_cannot_manage_delivery_zones(): void
    {
        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $customerToken = $customer->createToken('auth-token')->plainTextToken;

        $this->withToken($customerToken)
            ->postJson('/api/v1/admin/delivery-zones', ['name' => 'Nope'])
            ->assertForbidden();
    }

    /** @param array<string, mixed> $boundary */
    private function zonePayload(string $name, array $boundary): array
    {
        return [
            'name' => $name,
            'city' => 'Cabanatuan City',
            'province' => 'Nueva Ecija',
            'status' => 'ACTIVE',
            'boundary_geojson' => $boundary,
            'base_fee' => 50,
            'included_km' => 5,
            'extra_fee_per_km' => 10,
            'distance_rounding_km' => 0.5,
        ];
    }
}
