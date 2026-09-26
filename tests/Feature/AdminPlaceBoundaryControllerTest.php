<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class AdminPlaceBoundaryControllerTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolePermissionSeeder::class);
        Cache::flush();
    }

    public function test_returns_and_caches_philippine_multipolygon_boundaries_for_an_admin(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://nominatim.openstreetmap.org/search*' => Http::response([$this->nominatimResult()]),
        ]);
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $token = $admin->createToken('auth-token')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/v1/admin/place-boundaries?query=Cabanatuan%2C%20Nueva%20Ecija&type=city')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Cabanatuan')
            ->assertJsonPath('data.0.city', 'Cabanatuan')
            ->assertJsonPath('data.0.province', 'Nueva Ecija')
            ->assertJsonPath('data.0.geometry.type', 'MultiPolygon');

        $this->travel(1)->seconds();

        $this->withToken($token)
            ->getJson('/api/v1/admin/place-boundaries?query=Cabanatuan%2C%20Nueva%20Ecija&type=city')
            ->assertOk();

        Http::assertSentCount(1);
        Http::assertSent(fn (Request $request): bool => $request['countrycodes'] === 'ph'
            && $request['polygon_geojson'] === 1
            && $request['featureType'] === 'city'
            && str_contains($request->header('User-Agent')[0] ?? '', 'TalaDelivery'));
    }

    public function test_returns_422_when_boundary_query_is_missing(): void
    {
        Http::preventStrayRequests();
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);

        $this->withToken($admin->createToken('auth-token')->plainTextToken)
            ->getJson('/api/v1/admin/place-boundaries')
            ->assertUnprocessable()
            ->assertJsonValidationErrors('query');

        Http::assertNothingSent();
    }

    public function test_returns_503_when_boundary_provider_is_unavailable(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://nominatim.openstreetmap.org/search*' => Http::response([], 503),
        ]);
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);

        $this->withToken($admin->createToken('auth-token')->plainTextToken)
            ->getJson('/api/v1/admin/place-boundaries?query=Cabanatuan&type=city')
            ->assertServiceUnavailable()
            ->assertJsonPath('message', 'The boundary search service is temporarily unavailable.');

        Http::assertSentCount(1);
    }

    public function test_returns_403_when_customer_searches_boundaries(): void
    {
        Http::preventStrayRequests();
        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);

        $this->withToken($customer->createToken('auth-token')->plainTextToken)
            ->getJson('/api/v1/admin/place-boundaries?query=Cabanatuan&type=city')
            ->assertForbidden();

        Http::assertNothingSent();
    }

    /** @return array<string, mixed> */
    private function nominatimResult(): array
    {
        return [
            'place_id' => 123,
            'name' => 'Cabanatuan',
            'display_name' => 'Cabanatuan, Nueva Ecija, Central Luzon, Philippines',
            'addresstype' => 'city',
            'address' => [
                'city' => 'Cabanatuan',
                'state' => 'Nueva Ecija',
                'country_code' => 'ph',
            ],
            'boundingbox' => ['15.40', '15.60', '120.80', '121.10'],
            'geojson' => [
                'type' => 'MultiPolygon',
                'coordinates' => [[[[120.8, 15.4], [121.1, 15.4], [121.1, 15.6], [120.8, 15.4]]]],
            ],
        ];
    }
}
