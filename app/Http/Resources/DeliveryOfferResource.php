<?php

namespace App\Http\Resources;

use App\Models\DeliveryOffer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin DeliveryOffer */
class DeliveryOfferResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'delivery_id' => $this->delivery_id,
            'rider_id' => $this->rider_id,
            'status' => $this->status?->value,
            'offered_at' => $this->offered_at,
            'expires_at' => $this->expires_at,
            'responded_at' => $this->responded_at,
            'created_at' => $this->created_at,
            'delivery' => new DeliveryResource($this->whenLoaded('delivery')),
        ];
    }
}
