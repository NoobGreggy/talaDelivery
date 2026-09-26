<?php

namespace App\Services;

use App\Enums\DeliveryZoneStatus;
use App\Models\DeliveryZone;
use App\Models\PlatformSetting;
use Illuminate\Support\Str;

class PricingService
{
    public function __construct(
        private RoadDistanceService $roadDistance,
        private ZoneBoundaryService $boundaries,
    ) {}

    /**
     * @return array{delivery_fee: float, distance_km: float, billable_distance_km: float, distance_method: string, zone: DeliveryZone}
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

        $zone = $this->resolveZone($city, $province, $deliveryLat, $deliveryLng);

        return $this->calculateForZone($zone, $pickupLat, $pickupLng, $deliveryLat, $deliveryLng);
    }

    /**
     * @return array{delivery_fee: float, distance_km: float, billable_distance_km: float, distance_method: string, zone: DeliveryZone}
     */
    public function calculateForZone(
        DeliveryZone $zone,
        float $pickupLat,
        float $pickupLng,
        float $deliveryLat,
        float $deliveryLng,
        ?string $distanceMethod = null,
    ): array {
        $method = $distanceMethod ?? PlatformSetting::current()->distance_method;
        $distanceKm = $method === 'ROAD_ROUTE'
            ? $this->roadDistance->distanceKm($pickupLat, $pickupLng, $deliveryLat, $deliveryLng)
            : $this->distanceKm($pickupLat, $pickupLng, $deliveryLat, $deliveryLng);

        if ($distanceKm === null) {
            throw new \DomainException('Road distance is temporarily unavailable. Please try again.');
        }

        $maximumDistance = $zone->maximum_delivery_km !== null ? (float) $zone->maximum_delivery_km : null;
        if ($maximumDistance !== null && $distanceKm > $maximumDistance) {
            throw new \DomainException("Delivery distance exceeds this zone's {$maximumDistance} km limit.");
        }

        $baseFee = (float) $zone->base_fee;
        $includedKm = (float) $zone->included_km;
        $extraPerKm = (float) $zone->extra_fee_per_km;
        $roundingKm = max(0.1, (float) ($zone->distance_rounding_km ?? 0.1));
        $billableDistanceKm = ceil(($distanceKm / $roundingKm) - 0.0000001) * $roundingKm;

        $extraKm = max(0.0, $billableDistanceKm - $includedKm);
        $deliveryFee = $baseFee + ($extraPerKm * $extraKm);
        if ($zone->maximum_delivery_fee !== null) {
            $deliveryFee = min($deliveryFee, (float) $zone->maximum_delivery_fee);
        }

        return [
            'delivery_fee' => round($deliveryFee, 2),
            'distance_km' => round($distanceKm, 2),
            'billable_distance_km' => round($billableDistanceKm, 2),
            'distance_method' => $method,
            'zone' => $zone,
        ];
    }

    public function resolveZone(
        ?string $city = null,
        ?string $province = null,
        ?float $deliveryLat = null,
        ?float $deliveryLng = null,
    ): DeliveryZone {
        $normalizedCity = Str::of($city ?? '')->squish()->lower()->toString();
        if ($normalizedCity === '') {
            throw new \DomainException('A city is required to calculate the delivery fee.');
        }

        $normalizedProvince = Str::of($province ?? '')->squish()->lower()->toString();
        if ($normalizedProvince === '') {
            throw new \DomainException('A province is required to calculate the delivery fee.');
        }

        $baseCity = Str::endsWith($normalizedCity, ' city')
            ? Str::beforeLast($normalizedCity, ' city')
            : $normalizedCity;
        $acceptedCityNames = array_values(array_unique([
            $baseCity,
            $baseCity.' city',
        ]));

        $zones = DeliveryZone::query()
            ->where('status', DeliveryZoneStatus::Active->value)
            ->where(fn ($query) => $query->whereNull('effective_from')->orWhere('effective_from', '<=', now()))
            ->orderBy('id')
            ->get();

        if ($deliveryLat !== null && $deliveryLng !== null) {
            $boundaryMatch = $zones->first(fn (DeliveryZone $zone): bool => is_array($zone->boundary_geojson)
                && $this->boundaries->covers($zone->boundary_geojson, $deliveryLat, $deliveryLng));

            if ($boundaryMatch !== null) {
                return $boundaryMatch;
            }
        }

        $matched = $zones->first(function (DeliveryZone $zone) use ($acceptedCityNames, $normalizedProvince): bool {
            if ($zone->boundary_geojson !== null) {
                return false;
            }

            $zoneCity = Str::of($zone->city ?? '')->squish()->lower()->toString();
            $zoneProvince = Str::of($zone->province ?? '')->squish()->lower()->toString();

            return in_array($zoneCity, $acceptedCityNames, true) && $zoneProvince === $normalizedProvince;
        });

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
