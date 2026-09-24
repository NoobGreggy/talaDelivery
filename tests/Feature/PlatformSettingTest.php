<?php

namespace Tests\Feature;

use App\Enums\Role;
use App\Models\PlatformSetting;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;

class PlatformSettingTest extends ApiTestCase
{
    public function test_first_platform_settings_read_returns_the_default_values(): void
    {
        $this->seed(RolePermissionSeeder::class);
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);

        $this->withToken($admin->createToken('auth-token')->plainTextToken)
            ->getJson('/api/v1/admin/settings')
            ->assertOk()
            ->assertJsonPath('data.rider_commission_type', 'PERCENTAGE')
            ->assertJsonPath('data.rider_commission_value', '0.00')
            ->assertJsonPath('data.earnings_week_type', 'ROLLING_SEVEN_DAYS')
            ->assertJsonPath('data.settlement_timezone', 'Asia/Manila')
            ->assertJsonPath('data.settlement_day_starts_at', '00:00:00')
            ->assertJsonPath('data.distance_method', 'STRAIGHT_LINE');

        $this->assertDatabaseHas('platform_settings', [
            'key' => 'platform',
            'settlement_timezone' => 'Asia/Manila',
            'settlement_day_starts_at' => '00:00:00',
        ]);
    }

    public function test_platform_admin_can_update_dynamic_rider_calculation_settings(): void
    {
        $this->seed(RolePermissionSeeder::class);
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);
        $token = $admin->createToken('auth-token')->plainTextToken;

        $this->withToken($token)->putJson('/api/v1/admin/settings', [
            'rider_commission_type' => 'PERCENTAGE',
            'rider_commission_value' => 22.5,
            'earnings_week_type' => 'CALENDAR_WEEK',
            'week_starts_on' => 1,
            'settlement_timezone' => 'Asia/Manila',
            'settlement_day_starts_at' => '00:00',
            'distance_method' => 'STRAIGHT_LINE',
        ])->assertOk()
            ->assertJsonPath('data.rider_commission_value', '22.50')
            ->assertJsonPath('data.earnings_week_type', 'CALENDAR_WEEK');

        $this->assertDatabaseHas('platform_settings', [
            'rider_commission_type' => 'PERCENTAGE',
            'rider_commission_value' => 22.5,
            'settlement_timezone' => 'Asia/Manila',
        ]);
    }

    public function test_percentage_commission_above_one_hundred_returns_422(): void
    {
        $this->seed(RolePermissionSeeder::class);
        $admin = User::factory()->create(['role' => Role::PlatformAdmin->value]);
        $admin->assignRole(Role::PlatformAdmin->value);

        $this->withToken($admin->createToken('auth-token')->plainTextToken)
            ->putJson('/api/v1/admin/settings', [
                'rider_commission_type' => 'PERCENTAGE',
                'rider_commission_value' => 101,
                'earnings_week_type' => 'ROLLING_SEVEN_DAYS',
                'week_starts_on' => 1,
                'settlement_timezone' => 'Asia/Manila',
                'settlement_day_starts_at' => '00:00',
                'distance_method' => 'STRAIGHT_LINE',
            ])->assertUnprocessable()
            ->assertJsonValidationErrors('rider_commission_value');

        $this->assertDatabaseCount('platform_settings', 0);
    }

    public function test_non_admin_cannot_read_platform_settings(): void
    {
        $this->seed(RolePermissionSeeder::class);
        PlatformSetting::factory()->create();
        $customer = User::factory()->create(['role' => Role::Customer->value]);
        $customer->assignRole(Role::Customer->value);

        $this->withToken($customer->createToken('auth-token')->plainTextToken)
            ->getJson('/api/v1/admin/settings')
            ->assertForbidden();
    }
}
