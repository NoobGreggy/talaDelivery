<?php

namespace Database\Factories;

use App\Models\Order;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Order>
 */
class OrderFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_number' => 'TLD-'.strtoupper(Str::random(10)),
            'customer_id' => User::factory(),
            'store_id' => Store::factory(),
            'subtotal' => 0,
            'delivery_fee' => 0,
            'discount' => 0,
            'total' => 0,
            'payment_method' => 'COD',
            'payment_status' => 'PENDING',
            'status' => 'PENDING',
            'customer_name' => fake()->name(),
            'customer_phone' => fake()->phoneNumber(),
            'delivery_address' => fake()->address(),
            'delivery_latitude' => fake()->latitude(),
            'delivery_longitude' => fake()->longitude(),
            'notes' => null,
        ];
    }
}
