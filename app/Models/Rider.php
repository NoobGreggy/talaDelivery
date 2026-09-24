<?php

namespace App\Models;

use App\Enums\DeliveryStatus;
use App\Enums\RiderStatus;
use App\Enums\VehicleType;
use Database\Factories\RiderFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable(['user_id', 'vehicle_type', 'vehicle_plate', 'license_number', 'requirements', 'is_online', 'status', 'current_latitude', 'current_longitude', 'current_location_updated_at'])]
class Rider extends Model
{
    /** @use HasFactory<RiderFactory> */
    use HasFactory;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'vehicle_type' => VehicleType::class,
            'is_online' => 'boolean',
            'status' => RiderStatus::class,
            'current_latitude' => 'decimal:7',
            'current_longitude' => 'decimal:7',
            'current_location_updated_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Deliveries assigned to this rider (deliveries reference the rider's user id).
     *
     * @return HasMany<Delivery>
     */
    public function deliveries(): HasMany
    {
        return $this->hasMany(Delivery::class, 'rider_id', 'user_id');
    }

    /**
     * The delivery the rider is currently working on.
     *
     * @return HasOne<Delivery>
     */
    public function currentDelivery(): HasOne
    {
        return $this->hasOne(Delivery::class, 'rider_id', 'user_id')
            ->whereIn('status', [
                DeliveryStatus::Assigned,
                DeliveryStatus::Accepted,
                DeliveryStatus::PickedUp,
                DeliveryStatus::InTransit,
            ]);
    }
}
