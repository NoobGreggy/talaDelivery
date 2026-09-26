<?php

namespace App\Models;

use App\Enums\DeliveryZoneStatus;
use Database\Factories\DeliveryZoneFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name', 'city', 'province', 'boundary_geojson', 'base_fee', 'included_km', 'maximum_delivery_km', 'extra_fee_per_km', 'maximum_delivery_fee', 'distance_rounding_km', 'effective_from', 'status', 'created_by', 'updated_by'])]
class DeliveryZone extends Model
{
    /** @use HasFactory<DeliveryZoneFactory> */
    use HasFactory;

    /** @return BelongsTo<User, $this> */
    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** @return BelongsTo<User, $this> */
    public function updatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by');
    }

    /** @return HasMany<DeliveryZoneRevision, $this> */
    public function revisions(): HasMany
    {
        return $this->hasMany(DeliveryZoneRevision::class);
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'boundary_geojson' => 'array',
            'base_fee' => 'decimal:2',
            'included_km' => 'decimal:2',
            'maximum_delivery_km' => 'decimal:2',
            'extra_fee_per_km' => 'decimal:2',
            'maximum_delivery_fee' => 'decimal:2',
            'distance_rounding_km' => 'decimal:2',
            'effective_from' => 'datetime',
            'status' => DeliveryZoneStatus::class,
        ];
    }
}
