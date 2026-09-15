<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;

class RiderApprovalTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_rider_registration_starts_as_pending(): void
    {
        $response = $this->postJson('/api/v1/rider/register', [
            'name' => 'New Rider',
            'email' => 'pending@example.com',
            'password' => 'password123',
            'vehicle_type' => 'MOTORCYCLE',
            'vehicle_plate' => 'AAA-111',
            'license_number' => 'N-1234567',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.user.rider.status', 'PENDING');

        $this->assertSame('PENDING', $response->json('data.user.rider.status'));
    }

    public function test_pending_rider_cannot_go_online(): void
    {
        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => 'PENDING',
        ]);
        $token = $riderUser->createToken('auth-token')->plainTextToken;

        $this->withToken($token)
            ->postJson('/api/v1/rider/online')
            ->assertForbidden()
            ->assertJsonPath('message', 'Your application is still pending admin approval.');
    }

    public function test_rejected_rider_cannot_go_online(): void
    {
        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => 'REJECTED',
        ]);
        $token = $riderUser->createToken('auth-token')->plainTextToken;

        $this->withToken($token)
            ->postJson('/api/v1/rider/online')
            ->assertForbidden();
    }

    public function test_admin_can_approve_rider_and_rider_can_then_go_online(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $rider = $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => 'PENDING',
        ]);
        $riderToken = $riderUser->createToken('auth-token')->plainTextToken;

        $this->withToken($adminToken)
            ->postJson("/api/v1/admin/riders/{$rider->id}/approve")
            ->assertOk()
            ->assertJsonPath('data.status', 'OFFLINE');

        auth()->forgetGuards();

        $this->withToken($riderToken)
            ->postJson('/api/v1/rider/online')
            ->assertOk()
            ->assertJsonPath('data.status', 'ONLINE');
    }

    public function test_admin_can_reject_rider(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $rider = $riderUser->rider()->create([
            'vehicle_type' => 'MOTORCYCLE',
            'status' => 'PENDING',
        ]);

        $this->withToken($adminToken)
            ->postJson("/api/v1/admin/riders/{$rider->id}/reject", ['reason' => 'Invalid license'])
            ->assertOk()
            ->assertJsonPath('data.status', 'REJECTED');
    }

    public function test_non_admin_cannot_approve_riders(): void
    {
        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $customerToken = $customer->createToken('auth-token')->plainTextToken;

        $riderUser = User::factory()->create(['role' => Role::Rider->value]);
        $riderUser->assignRole(Role::Rider->value);
        $rider = $riderUser->rider()->create(['status' => 'PENDING']);

        $this->withToken($customerToken)
            ->postJson("/api/v1/admin/riders/{$rider->id}/approve")
            ->assertForbidden();
    }
}
