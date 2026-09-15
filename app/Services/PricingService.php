<?php

namespace App\Services;

use App\Models\DeliveryZone;

class PricingService
{
    /**
     * @return array{delivery_fee: float, distance_km: float, zone: DeliveryZone|null}
     */
    public function calculate(
        ?float $pickupLat,
        ?float $pickupLng,
        ?float $deliveryLat,
        ?float $deliveryLng,
        ?string $city = null,
        ?string $province = null,
    ): array {
        $zone = $this->resolveZone($city, $province);
        $distanceKm = $this->distanceKm($pickupLat, $pickupLng, $deliveryLat, $deliveryLng);

        $baseFee = (float) $zone->base_fee;
        $includedKm = (float) $zone->included_km;
        $extraPerKm = (float) $zone->extra_fee_per_km;

        $extraKm = max(0.0, $distanceKm - $includedKm);
        $deliveryFee = $baseFee + ($extraPerKm * $extraKm);

        return [
            'delivery_fee' => round($deliveryFee, 2),
            'distance_km' => round($distanceKm, 2),
            'zone' => $zone,
        ];
    }

    public function resolveZone(?string $city = null, ?string $province = null): DeliveryZone
    {
        $zone = DeliveryZone::where('status', 'ACTIVE');

        if ($city !== null) {
            $zone = $zone->where('city', $city);
        }

        $matched = $zone->first();

        if ($matched) {
            return $matched;
        }

        return DeliveryZone::where('status', 'ACTIVE')->first()
            ?? new DeliveryZone([
                'base_fee' => 49,
                'included_km' => 5,
                'extra_fee_per_km' => 10,
            ]);
    }

    public function distanceKm(?float $fromLat, ?float $fromLng, ?float $toLat, ?float $toLng): float
    {
        if ($fromLat === null || $fromLng === null || $toLat === null || $toLng === null) {
            return 0.0;
        }

        $earthRadiusKm = 6371.0;

        $dLat = deg2rad($toLat - $fromLat);
        $dLng = deg2rad($toLng - $fromLng);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($fromLat)) * cos(deg2rad($toLat)) * sin($dLng / 2) ** 2;

        return $earthRadiusKm * (2 * atan2(sqrt($a), sqrt(1 - $a)));
    }
}
