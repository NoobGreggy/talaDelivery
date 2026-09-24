<?php

namespace App\Http\Resources;

use App\Enums\DeliveryStatus;
use App\Models\Delivery;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Delivery */
class DeliveryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $isTrackable = in_array($this->status, [
            DeliveryStatus::Assigned,
            DeliveryStatus::Accepted,
            DeliveryStatus::PickedUp,
            DeliveryStatus::InTransit,
        ], true);
        $riderProfile = $isTrackable && $this->relationLoaded('rider') && $this->rider?->relationLoaded('rider')
            ? $this->rider->rider
            : null;

        return [
            'id' => $this->id,
            'order_id' => $this->order_id,
            'store_id' => $this->store_id,
            'status' => $this->status?->value,
            'rider' => new UserResource($this->whenLoaded('rider')),
            'rider_location' => $riderProfile === null ? null : [
                'latitude' => $riderProfile->current_latitude,
                'longitude' => $riderProfile->current_longitude,
                'recorded_at' => $riderProfile->current_location_updated_at,
            ],
            'pickup_address' => $this->pickup_address,
            'pickup_latitude' => $this->pickup_latitude,
            'pickup_longitude' => $this->pickup_longitude,
            'delivery_address' => $this->delivery_address,
            'delivery_latitude' => $this->delivery_latitude,
            'delivery_longitude' => $this->delivery_longitude,
            'distance_km' => $this->distance_km,
            'delivery_fee' => $this->delivery_fee,
            'rider_commission' => $this->rider_commission,
            'commission_type' => $this->commission_type,
            'commission_value' => $this->commission_value,
            'cancelled_by' => $this->cancelled_by,
            'cancellation_reason' => $this->cancellation_reason,
            'assigned_at' => $this->assigned_at,
            'accepted_at' => $this->accepted_at,
            'picked_up_at' => $this->picked_up_at,
            'started_at' => $this->started_at,
            'delivered_at' => $this->delivered_at,
            'cancelled_at' => $this->cancelled_at,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
            'order' => new OrderResource($this->whenLoaded('order')),
            'store' => new StoreResource($this->whenLoaded('store')),
            'offers' => DeliveryOfferResource::collection($this->whenLoaded('offers')),
        ];
    }
}
