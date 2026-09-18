<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\Category;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreUser;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;

class StoreProductTest extends ApiTestCase
{
    private Store $store;

    private Category $category;

    private User $storeAdmin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);

        $this->store = Store::factory()->create();
        $this->category = Category::factory()->create(['store_id' => $this->store->id]);

        $this->storeAdmin = User::factory()->create(['role' => Role::StoreAdmin->value]);
        $this->storeAdmin->assignRole(Role::StoreAdmin->value);
        StoreUser::create([
            'store_id' => $this->store->id,
            'user_id' => $this->storeAdmin->id,
            'role' => 'store_admin',
        ]);
    }

    public function test_store_can_create_product_with_base64_image(): void
    {
        $png = $this->tinyPngImage();

        $response = $this->asStoreAdmin()
            ->postJson('/api/v1/store/products', [
                'name' => 'Burger',
                'price' => 99,
                'category_id' => $this->category->id,
                'image' => $png,
            ]);

        $response->assertCreated()
            ->assertJsonPath('data.name', 'Burger')
            ->assertJsonPath('data.image', $png);

        $this->assertDatabaseHas('products', ['name' => 'Burger']);
        $this->assertSame($png, Product::where('name', 'Burger')->firstOrFail()->image);
    }

    public function test_image_above_5_mb_is_rejected(): void
    {
        $oversized = 'data:image/png;base64,'.base64_encode(str_repeat('a', (5 * 1024 * 1024) + 1));

        $this->asStoreAdmin()
            ->postJson('/api/v1/store/products', [
                'name' => 'Big Burger',
                'price' => 99,
                'image' => $oversized,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['image']);
    }

    public function test_non_image_base64_is_rejected(): void
    {
        $this->asStoreAdmin()
            ->postJson('/api/v1/store/products', [
                'name' => 'Weird Burger',
                'price' => 99,
                'image' => 'data:text/plain;base64,'.base64_encode('hello'),
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['image']);
    }

    public function test_invalid_base64_is_rejected(): void
    {
        $this->asStoreAdmin()
            ->postJson('/api/v1/store/products', [
                'name' => 'Broken Burger',
                'price' => 99,
                'image' => 'data:image/png;base64,@@@not-base64@@@',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['image']);
    }

    private function tinyPngImage(): string
    {
        return 'data:image/png;base64,'.base64_encode("\x89PNG\r\n\x1a\n");
    }

    protected function asStoreAdmin(): static
    {
        auth()->forgetGuards();

        $token = $this->storeAdmin->createToken('auth-token')->plainTextToken;

        return $this->withToken($token)
            ->withHeader('X-Store-Id', (string) $this->store->id);
    }
}
