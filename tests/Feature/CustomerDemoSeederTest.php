<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\Product;
use App\Models\User;
use Database\Seeders\CustomerDemoSeeder;
use Illuminate\Support\Facades\Hash;

class CustomerDemoSeederTest extends ApiTestCase
{
    public function test_creates_a_customer_ready_demo_catalog(): void
    {
        $this->seed(CustomerDemoSeeder::class);

        $customer = User::query()->where('email', 'customer@taladelivery.test')->firstOrFail();
        $productsHaveMatchingCategories = Product::query()
            ->with('category')
            ->get()
            ->every(fn (Product $product): bool => $product->category?->store_id === $product->store_id);

        $this->assertSame(Role::Customer, $customer->role);
        $this->assertTrue($customer->hasRole(Role::Customer->value));
        $this->assertTrue(Hash::check('password123', $customer->password));
        $this->assertTrue($productsHaveMatchingCategories);
        $this->assertDatabaseCount('stores', 3);
        $this->assertDatabaseCount('categories', 6);
        $this->assertDatabaseCount('products', 18);
        $this->assertDatabaseCount('delivery_zones', 1);
        $this->assertDatabaseHas('addresses', [
            'user_id' => $customer->id,
            'city' => 'Cauayan City',
            'is_default' => true,
        ]);
    }

    public function test_demo_customer_can_log_in_and_browse_the_seeded_catalog(): void
    {
        $this->seed(CustomerDemoSeeder::class);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'customer@taladelivery.test',
            'password' => 'password123',
        ])->assertOk()
            ->assertJsonPath('data.user.role', Role::Customer->value);

        $this->getJson('/api/v1/stores?per_page=50')
            ->assertOk()
            ->assertJsonCount(3, 'data.data');

        $this->getJson('/api/v1/products?per_page=50')
            ->assertOk()
            ->assertJsonCount(18, 'data.data');
    }

    public function test_can_run_repeatedly_without_creating_duplicates(): void
    {
        $this->seed(CustomerDemoSeeder::class);

        $this->seed(CustomerDemoSeeder::class);

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('addresses', 1);
        $this->assertDatabaseCount('stores', 3);
        $this->assertDatabaseCount('categories', 6);
        $this->assertDatabaseCount('products', 18);
        $this->assertDatabaseCount('delivery_zones', 1);
    }

    public function test_does_not_create_demo_data_in_production(): void
    {
        $this->app->detectEnvironment(fn (): string => 'production');

        $this->app->make(CustomerDemoSeeder::class)->run();

        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('stores', 0);
        $this->assertDatabaseCount('products', 0);
    }
}
