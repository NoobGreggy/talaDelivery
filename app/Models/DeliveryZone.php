<?php

namespace App\Models;

use App\Enums\StoreStatus;
use Database\Factories\DeliveryZoneFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['name', 'city', 'province', 'base_fee', 'included_km', 'extra_fee_per_km', 'status'])]
class DeliveryZone extends Model
{
    /** @use HasFactory<DeliveryZoneFactory> */
    use HasFactory;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'base_fee' => 'decimal:2',
            'included_km' => 'decimal:2',
            'extra_fee_per_km' => 'decimal:2',
            'status' => StoreStatus::class,
        ];
    }
}
