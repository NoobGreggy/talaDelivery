<?php

namespace Database\Factories;

use App\Models\PlatformSetting;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<PlatformSetting>
 */
class PlatformSettingFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'key' => 'platform',
            'rider_commission_type' => 'PERCENTAGE',
            'rider_commission_value' => 20,
            'earnings_week_type' => 'ROLLING_SEVEN_DAYS',
            'week_starts_on' => 1,
            'settlement_timezone' => 'Asia/Manila',
            'settlement_day_starts_at' => '00:00:00',
            'distance_method' => 'STRAIGHT_LINE',
        ];
    }
}
