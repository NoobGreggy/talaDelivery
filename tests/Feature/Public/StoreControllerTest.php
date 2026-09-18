<?php

namespace Tests\Feature\Public;

use App\Models\Category;
use App\Models\Store;
use Tests\Feature\ApiTestCase;

class StoreControllerTest extends ApiTestCase
{
    public function test_search_is_case_insensitive_and_only_returns_active_stores(): void
    {
        $activeStore = Store::factory()->create([
            'name' => 'CarePlus Pharmacy',
            'description' => 'Daily health essentials.',
            'status' => 'ACTIVE',
        ]);
        Store::factory()->create([
            'name' => 'Closed Shop',
            'description' => 'Former CarePlus location.',
            'status' => 'INACTIVE',
        ]);

        $this->getJson('/api/v1/stores?search=careplus')
            ->assertOk()
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $activeStore->id);
    }

    public function test_store_list_includes_only_active_categories_for_the_customer_dashboard(): void
    {
        $store = Store::factory()->create(['status' => 'ACTIVE']);
        $active = Category::factory()->create([
            'store_id' => $store->id,
            'name' => 'Groceries',
            'status' => 'ACTIVE',
        ]);
        Category::factory()->create([
            'store_id' => $store->id,
            'name' => 'Hidden',
            'status' => 'INACTIVE',
        ]);

        $this->getJson('/api/v1/stores')
            ->assertOk()
            ->assertJsonPath('data.data.0.id', $store->id)
            ->assertJsonCount(1, 'data.data.0.categories')
            ->assertJsonPath('data.data.0.categories.0.id', $active->id);
    }
}
