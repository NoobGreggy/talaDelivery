<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\DeliveryZone;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;

class AdminDeliveryZoneTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_admin_can_create_list_update_and_delete_delivery_zones(): void
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
            ->assertJsonPath('data.status', 'INACTIVE');

        $this->withToken($adminToken)
            ->deleteJson("/api/v1/admin/delivery-zones/{$zoneId}")
            ->assertOk();

        $this->assertDatabaseMissing('delivery_zones', ['id' => $zoneId]);
    }

    public function test_admin_created_zone_is_used_by_pricing(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        $this->withToken($adminToken)
            ->postJson('/api/v1/admin/delivery-zones', [
                'name' => 'Bulacan Zone',
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
}
