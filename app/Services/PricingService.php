<?php

namespace App\Services;

use App\Models\DeliveryZone;
use Illuminate\Support\Str;

class PricingService
{
    /**
     * @return array{delivery_fee: float, distance_km: float, zone: DeliveryZone}
     */
    public function calculate(
        ?float $pickupLat,
        ?float $pickupLng,
        ?float $deliveryLat,
        ?float $deliveryLng,
        ?string $city = null,
        ?string $province = null,
    ): array {
        if ($pickupLat === null || $pickupLng === null || $deliveryLat === null || $deliveryLng === null) {
            throw new \DomainException('A valid pickup and delivery location is required to place an order.');
        }

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
        $normalizedCity = Str::of($city ?? '')->squish()->lower()->toString();
        if ($normalizedCity === '') {
            throw new \DomainException('A city is required to calculate the delivery fee.');
        }

        $matched = DeliveryZone::query()
            ->where('status', 'ACTIVE')
            ->whereRaw('LOWER(TRIM(city)) = ?', [$normalizedCity])
            ->orderBy('id')
            ->first();

        if (! $matched) {
            throw new \DomainException('Delivery is not available in the selected city.');
        }

        return $matched;
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
