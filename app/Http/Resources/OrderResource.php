<?php

namespace App\Http\Resources;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Order */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_number' => $this->order_number,
            'status' => $this->status?->value,
            'status_label' => $this->status?->label(),
            'payment_method' => $this->payment_method?->value,
            'payment_status' => $this->payment_status?->value,
            'subtotal' => $this->subtotal,
            'delivery_fee' => $this->delivery_fee,
            'discount' => $this->discount,
            'total' => $this->total,
            'customer_name' => $this->customer_name,
            'customer_phone' => $this->customer_phone,
            'delivery_address' => $this->delivery_address,
            'delivery_latitude' => $this->delivery_latitude,
            'delivery_longitude' => $this->delivery_longitude,
            'notes' => $this->notes,
            'cancelled_by' => $this->cancelled_by,
            'cancellation_reason' => $this->cancellation_reason,
            'confirmed_at' => $this->confirmed_at,
            'prepared_at' => $this->prepared_at,
            'ready_at' => $this->ready_at,
            'delivered_at' => $this->delivered_at,
            'cancelled_at' => $this->cancelled_at,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
            'customer' => new UserResource($this->whenLoaded('customer')),
            'store' => new StoreResource($this->whenLoaded('store')),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            'delivery' => new DeliveryResource($this->whenLoaded('delivery')),
        ];
    }
}
