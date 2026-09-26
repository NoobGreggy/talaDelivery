<?php

namespace App\Http\Resources;

use App\Models\DeliveryZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin DeliveryZone */
class DeliveryZoneResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'city' => $this->city,
            'province' => $this->province,
            'boundary_geojson' => $this->boundary_geojson,
            'base_fee' => $this->base_fee,
            'included_km' => $this->included_km,
            'maximum_delivery_km' => $this->maximum_delivery_km,
            'extra_fee_per_km' => $this->extra_fee_per_km,
            'maximum_delivery_fee' => $this->maximum_delivery_fee,
            'distance_rounding_km' => $this->distance_rounding_km,
            'effective_from' => $this->effective_from,
            'status' => $this->status?->value,
            'updated_by' => $this->whenLoaded('updatedBy', fn () => [
                'id' => $this->updatedBy?->id,
                'name' => $this->updatedBy?->name,
            ]),
            'revision_count' => $this->whenCounted('revisions'),
            'revisions' => $this->whenLoaded('revisions', fn () => $this->revisions->map(fn ($revision) => [
                'id' => $revision->id,
                'action' => $revision->action,
                'before' => $revision->before,
                'after' => $revision->after,
                'user' => $revision->user === null ? null : [
                    'id' => $revision->user->id,
                    'name' => $revision->user->name,
                ],
                'created_at' => $revision->created_at,
            ])),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
