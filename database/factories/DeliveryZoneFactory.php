<?php

namespace Database\Factories;

use App\Models\DeliveryZone;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DeliveryZone>
 */
class DeliveryZoneFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->unique()->city().' Zone',
            'city' => fake()->city(),
            'province' => fake()->state(),
            'base_fee' => 49,
            'included_km' => 5,
            'maximum_delivery_km' => null,
            'extra_fee_per_km' => 10,
            'maximum_delivery_fee' => null,
            'distance_rounding_km' => 0.10,
            'status' => 'ACTIVE',
        ];
    }
}
