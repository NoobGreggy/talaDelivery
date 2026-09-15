<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Support\Facades\Hash;

class AuthTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
    }

    public function test_customer_can_register(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Jane Customer',
            'email' => 'jane@example.com',
            'phone' => '09171234567',
            'password' => 'password123',
        ]);

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'name', 'email', 'roles']]]);

        $user = User::where('email', 'jane@example.com')->firstOrFail();

        $this->assertTrue($user->hasRole(Role::Customer->value));
        $this->assertSame('customer', $user->role->value);
    }

    public function test_user_can_login_and_receive_token(): void
    {
        $user = User::factory()->create([
            'email' => 'login@example.com',
            'password' => 'password123',
            'role' => Role::Customer->value,
        ]);
        $user->assignRole(Role::Customer->value);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'login@example.com',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['token', 'user']]);
    }

    public function test_login_fails_with_invalid_credentials(): void
    {
        User::factory()->create([
            'email' => 'login@example.com',
            'password' => 'password123',
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'login@example.com',
            'password' => 'wrong-password',
        ]);

        $response->assertUnauthorized()->assertJsonPath('success', false);
    }

    public function test_suspended_user_cannot_login(): void
    {
        User::factory()->create([
            'email' => 'suspended@example.com',
            'password' => 'password123',
            'status' => 'SUSPENDED',
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'suspended@example.com',
            'password' => 'password123',
        ]);

        $response->assertForbidden();
    }

    public function test_authenticated_user_can_fetch_profile(): void
    {
        $user = User::factory()->create(['role' => Role::Customer->value]);
        $user->assignRole(Role::Customer->value);
        $token = $user->createToken('auth-token')->plainTextToken;

        $response = $this->withToken($token)->getJson('/api/v1/auth/me');

        $response->assertOk()
            ->assertJsonPath('data.email', $user->email)
            ->assertJsonPath('data.roles.0', Role::Customer->value);
    }

    public function test_logout_revokes_token(): void
    {
        $user = User::factory()->create(['role' => Role::Customer->value]);
        $user->assignRole(Role::Customer->value);
        $token = $user->createToken('auth-token')->plainTextToken;

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();

        auth()->forgetGuards();

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_password_is_hashed(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Hash Tester',
            'email' => 'hash@example.com',
            'password' => 'password123',
        ])->assertCreated();

        $user = User::where('email', 'hash@example.com')->firstOrFail();

        $this->assertNotSame('password123', $user->password);
        $this->assertTrue(Hash::check('password123', $user->password));
    }

    public function test_registration_requires_valid_data(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'email' => 'not-an-email',
        ])->assertUnprocessable()
            ->assertJsonPath('success', false)
            ->assertJsonStructure(['errors' => ['name', 'email', 'password']]);
    }
}
