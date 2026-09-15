<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin User */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'role' => $this->role?->value,
            'status' => $this->status?->value,
            'roles' => $this->getRoleNames(),
            'permissions' => $this->getAllPermissions()->pluck('name'),
            'created_at' => $this->created_at,
            'rider' => new RiderResource($this->whenLoaded('rider')),
            'stores' => StoreResource::collection($this->whenLoaded('stores')),
            'orders_count' => $this->orders_count ?? 0,
            'total_spent' => $this->total_spent ?? 0,
        ];
    }
}
