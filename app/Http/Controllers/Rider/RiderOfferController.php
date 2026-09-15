<?php

namespace App\Http\Controllers\Rider;

use App\Enums\DeliveryOfferStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryOfferResource;
use App\Models\DeliveryOffer;
use App\Services\RiderMatchingService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RiderOfferController extends Controller
{
    public function __construct(public RiderMatchingService $matching) {}

    public function index(Request $request): JsonResponse
    {
        $offers = DeliveryOffer::where('rider_id', $request->user()->id)
            ->where('status', DeliveryOfferStatus::Pending)
            ->where('expires_at', '>', now())
            ->with(['delivery.order.items', 'delivery.store'])
            ->latest()
            ->get();

        return ApiResponse::success('Offers retrieved.', DeliveryOfferResource::collection($offers));
    }

    public function accept(Request $request, DeliveryOffer $offer): JsonResponse
    {
        try {
            $delivery = $this->matching->accept($offer, $request->user());
        } catch (\DomainException $e) {
            return ApiResponse::error($e->getMessage(), null, 422);
        }

        return ApiResponse::success('Offer accepted.', new DeliveryOfferResource($offer->fresh('delivery')));
    }

    public function reject(Request $request, DeliveryOffer $offer): JsonResponse
    {
        try {
            $offer = $this->matching->reject($offer, $request->user());
        } catch (\DomainException $e) {
            return ApiResponse::error($e->getMessage(), null, 422);
        }

        return ApiResponse::success('Offer rejected.', new DeliveryOfferResource($offer));
    }
}
