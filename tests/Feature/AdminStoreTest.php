<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\Store;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Support\Facades\Auth;

class AdminStoreTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_admin_can_create_store_with_merchant_account(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        $response = $this->withToken($adminToken)
            ->postJson('/api/v1/admin/stores', [
                'name' => 'Jollibee Cabanatuan',
                'description' => 'Fast food',
                'phone' => '09171234567',
                'email' => 'store@example.com',
                'address' => 'Maharlika Highway, Cabanatuan City',
                'opening_time' => '08:00',
                'closing_time' => '21:00',
                'merchant_name' => 'Juan Dela Cruz',
                'merchant_email' => 'juan@example.com',
                'merchant_password' => 'secret-password',
                'merchant_phone' => '09171112222',
            ])
            ->assertCreated()
            ->assertJsonPath('data.name', 'Jollibee Cabanatuan');

        $store = Store::where('name', 'Jollibee Cabanatuan')->firstOrFail();
        $owner = User::where('email', 'juan@example.com')->firstOrFail();

        $this->assertSame(Role::StoreAdmin->value, $owner->role->value);
        $this->assertTrue($owner->hasRole(Role::StoreAdmin->value));
        $this->assertDatabaseHas('store_users', [
            'store_id' => $store->id,
            'user_id' => $owner->id,
            'role' => Role::StoreAdmin->value,
        ]);

        // Merchant can log in and reach the store tenant scope.
        $ownerToken = $owner->createToken('auth-token')->plainTextToken;

        Auth::forgetGuards();

        $res = $this->withHeader('X-Store-Id', (string) $store->id)
            ->withToken($ownerToken)
            ->getJson('/api/v1/store/profile');

        $res->assertOk()
            ->assertJsonPath('data.id', $store->id);
    }

    public function test_merchant_email_must_be_unique(): void
    {
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $adminToken = $admin->createToken('auth-token')->plainTextToken;

        User::factory()->create(['email' => 'taken@example.com', 'role' => Role::Customer->value]);

        $this->withToken($adminToken)
            ->postJson('/api/v1/admin/stores', [
                'name' => 'Duplicate Email Store',
                'address' => 'Main Street',
                'merchant_name' => 'Tester',
                'merchant_email' => 'taken@example.com',
                'merchant_password' => 'secret-password',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('merchant_email');
    }

    public function test_non_admin_cannot_create_store(): void
    {
        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);
        $customerToken = $customer->createToken('auth-token')->plainTextToken;

        $this->withToken($customerToken)
            ->postJson('/api/v1/admin/stores', [
                'name' => 'Nope',
                'address' => 'Nowhere',
                'merchant_name' => 'Nope',
                'merchant_email' => 'nope@example.com',
                'merchant_password' => 'secret-password',
            ])
            ->assertForbidden();
    }
}
