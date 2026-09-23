<?php

namespace App\Services;

use App\Models\PlatformSetting;

class RiderCommissionService
{
    /**
     * @return array{amount: float, type: string, value: float}
     */
    public function calculate(float $deliveryFee, ?PlatformSetting $settings = null): array
    {
        $settings ??= PlatformSetting::current();
        $type = $settings->rider_commission_type;
        $value = (float) $settings->rider_commission_value;
        $amount = $type === 'FIXED'
            ? $value
            : $deliveryFee * ($value / 100);

        return [
            'amount' => round(max(0, $amount), 2),
            'type' => $type,
            'value' => $value,
        ];
    }
}
