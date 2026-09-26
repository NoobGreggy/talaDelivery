<?php

namespace Database\Factories;

use App\Models\DeliveryZone;
use App\Models\DeliveryZoneRevision;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DeliveryZoneRevision>
 */
class DeliveryZoneRevisionFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'delivery_zone_id' => DeliveryZone::factory(),
            'action' => 'UPDATED',
            'before' => ['base_fee' => 49],
            'after' => ['base_fee' => 59],
        ];
    }
}
