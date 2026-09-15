<?php

namespace Database\Factories;

use App\Models\Rider;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Rider>
 */
class RiderFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'vehicle_type' => fake()->randomElement(['MOTORCYCLE', 'BICYCLE', 'CAR']),
            'vehicle_plate' => strtoupper(fake()->bothify('### ???')),
            'license_number' => strtoupper(fake()->bothify('??-####')),
            'is_online' => false,
            'status' => 'PENDING',
            'current_latitude' => null,
            'current_longitude' => null,
        ];
    }
}
