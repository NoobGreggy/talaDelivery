<?php

namespace App\Http\Resources;

use App\Models\Rider;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Rider */
class RiderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'vehicle_type' => $this->vehicle_type?->value,
            'vehicle_plate' => $this->vehicle_plate,
            'license_number' => $this->license_number,
            'requirements' => $this->requirements,
            'is_online' => $this->is_online,
            'status' => $this->status?->value,
            'current_latitude' => $this->current_latitude,
            'current_longitude' => $this->current_longitude,
            'current_location_updated_at' => $this->current_location_updated_at,
            'completed_deliveries' => (int) ($this->completed_deliveries ?? 0),
            'total_earnings' => $this->total_earnings ?? 0,
            'created_at' => $this->created_at,
            'user' => new UserResource($this->whenLoaded('user')),
            'current_delivery' => new DeliveryResource($this->whenLoaded('currentDelivery')),
        ];
    }
}
