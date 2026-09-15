<?php

namespace Tests\Feature\Public;

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
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $activeStore->id);
    }
}
