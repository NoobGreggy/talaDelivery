<?php

namespace App\Http\Controllers\Admin;

use App\Enums\DeliveryOfferStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryResource;
use App\Models\Delivery;
use App\Models\DeliveryOffer;
use App\Models\User;
use App\Services\DeliveryService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDeliveryController extends Controller
{
    public function __construct(public DeliveryService $deliveries) {}

    public function index(Request $request): JsonResponse
    {
        $deliveries = Delivery::query()
            ->with(['order', 'store', 'rider.rider'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Deliveries retrieved.', DeliveryResource::collection($deliveries));
    }

    public function show(Delivery $delivery): JsonResponse
    {
        $delivery->load(['order.items', 'store', 'rider.rider', 'offers']);

        return ApiResponse::success('Delivery retrieved.', new DeliveryResource($delivery));
    }

    public function assign(Request $request, Delivery $delivery): JsonResponse
    {
        $validated = $request->validate([
            'rider_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        try {
            $delivery = $this->deliveries->assign($delivery, User::findOrFail($validated['rider_id']));
        } catch (\DomainException $e) {
            return ApiResponse::error($e->getMessage(), null, 422);
        }

        DeliveryOffer::query()
            ->where('delivery_id', $delivery->id)
            ->where('status', DeliveryOfferStatus::Pending)
            ->update(['status' => DeliveryOfferStatus::Expired]);

        return ApiResponse::success('Rider assigned to the delivery.', new DeliveryResource($delivery->load('order', 'rider.rider')));
    }

    public function cancel(Request $request, Delivery $delivery): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $delivery = $this->deliveries->cancel($delivery, 'admin', $validated['reason'] ?? null);

        return ApiResponse::success('Delivery cancelled.', new DeliveryResource($delivery->load('order')));
    }
}
