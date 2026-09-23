<?php

namespace App\Http\Resources;

use App\Models\PlatformSetting;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin PlatformSetting */
class PlatformSettingResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'rider_commission_type' => $this->rider_commission_type,
            'rider_commission_value' => $this->rider_commission_value,
            'earnings_week_type' => $this->earnings_week_type,
            'week_starts_on' => $this->week_starts_on,
            'settlement_timezone' => $this->settlement_timezone,
            'settlement_day_starts_at' => $this->settlement_day_starts_at,
            'distance_method' => $this->distance_method,
            'updated_at' => $this->updated_at,
        ];
    }
}
