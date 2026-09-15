<?php

namespace App\Http\Resources;

use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Product */
class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'store_id' => $this->store_id,
            'category_id' => $this->category_id,
            'name' => $this->name,
            'description' => $this->description,
            'sku' => $this->sku,
            'price' => $this->price,
            'image' => $this->image,
            'stock' => $this->stock,
            'is_available' => $this->is_available,
            'created_at' => $this->created_at,
            'category' => new CategoryResource($this->whenLoaded('category')),
        ];
    }
}
