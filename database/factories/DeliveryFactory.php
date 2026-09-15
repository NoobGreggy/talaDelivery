<?php

namespace Database\Factories;

use App\Models\Delivery;
use App\Models\Order;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Delivery>
 */
class DeliveryFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory(),
            'store_id' => Store::factory(),
            'rider_id' => null,
            'status' => 'UNASSIGNED',
            'pickup_address' => fake()->address(),
            'pickup_latitude' => fake()->latitude(),
            'pickup_longitude' => fake()->longitude(),
            'delivery_address' => fake()->address(),
            'delivery_latitude' => fake()->latitude(),
            'delivery_longitude' => fake()->longitude(),
            'distance_km' => fake()->randomFloat(2, 1, 15),
            'delivery_fee' => fake()->randomFloat(2, 40, 120),
        ];
    }
}
