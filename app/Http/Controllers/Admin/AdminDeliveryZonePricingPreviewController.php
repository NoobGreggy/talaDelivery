<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\PreviewDeliveryZonePricingRequest;
use App\Models\DeliveryZone;
use App\Services\PricingService;
use App\Services\RiderCommissionService;
use App\Services\ZoneBoundaryService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class AdminDeliveryZonePricingPreviewController extends Controller
{
    public function __construct(
        private PricingService $pricing,
        private RiderCommissionService $commissions,
        private ZoneBoundaryService $boundaries,
    ) {}

    public function __invoke(PreviewDeliveryZonePricingRequest $request): JsonResponse
    {
        $validated = $request->validated();
        $zone = new DeliveryZone($validated['zone']);
        $deliveryLatitude = (float) $validated['delivery_latitude'];
        $deliveryLongitude = (float) $validated['delivery_longitude'];

        if (is_array($zone->boundary_geojson)
            && ! $this->boundaries->covers($zone->boundary_geojson, $deliveryLatitude, $deliveryLongitude)) {
            return ApiResponse::success('Pricing preview completed.', [
                'covered' => false,
                'reason' => 'The delivery pin is outside this zone boundary.',
            ]);
        }

        try {
            $breakdown = $this->pricing->calculateForZone(
                $zone,
                (float) $validated['pickup_latitude'],
                (float) $validated['pickup_longitude'],
                $deliveryLatitude,
                $deliveryLongitude,
                $validated['distance_method'] ?? null,
            );
        } catch (\DomainException $exception) {
            return ApiResponse::success('Pricing preview completed.', [
                'covered' => false,
                'reason' => $exception->getMessage(),
            ]);
        }

        return ApiResponse::success('Pricing preview completed.', [
            'covered' => true,
            'delivery_fee' => $breakdown['delivery_fee'],
            'distance_km' => $breakdown['distance_km'],
            'billable_distance_km' => $breakdown['billable_distance_km'],
            'distance_method' => $breakdown['distance_method'],
            'rider_commission' => $this->commissions->calculate($breakdown['delivery_fee'])['amount'],
        ]);
    }
}
