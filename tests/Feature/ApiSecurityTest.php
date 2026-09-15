<?php

namespace Tests\Feature;

use App\Models\Store;

class ApiSecurityTest extends ApiTestCase
{
    public function test_request_without_app_key_is_rejected(): void
    {
        $this->withoutHeader('X-App-Key')
            ->getJson('/api/v1/stores')
            ->assertUnauthorized()
            ->assertJsonPath('success', false);
    }

    public function test_request_with_invalid_app_key_is_rejected(): void
    {
        $this->withHeader('X-App-Key', 'invalid-key')
            ->getJson('/api/v1/stores')
            ->assertUnauthorized();
    }

    public function test_request_with_valid_app_key_succeeds(): void
    {
        $this->getJson('/api/v1/stores')
            ->assertOk()
            ->assertJsonPath('success', true);
    }

    public function test_guest_rate_limit_returns_429_after_limit(): void
    {
        Store::factory()->create();

        for ($i = 0; $i < 60; $i++) {
            $this->getJson('/api/v1/stores')->assertOk();
        }

        $this->getJson('/api/v1/stores')
            ->assertStatus(429)
            ->assertJsonPath('success', false);
    }
}
