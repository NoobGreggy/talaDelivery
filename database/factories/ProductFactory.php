<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Product;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'store_id' => Store::factory(),
            'category_id' => Category::factory(),
            'name' => fake()->words(2, true),
            'description' => fake()->sentence(),
            'sku' => 'SKU-'.strtoupper(Str::random(8)),
            'price' => fake()->randomFloat(2, 10, 500),
            'image' => fake()->imageUrl(),
            'stock' => fake()->numberBetween(0, 100),
            'is_available' => true,
        ];
    }
}
