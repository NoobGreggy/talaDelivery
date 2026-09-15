<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryZoneResource;
use App\Models\DeliveryZone;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDeliveryZoneController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $zones = DeliveryZone::query()
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('search'), function ($query) use ($request): void {
                $query->where('name', 'like', '%'.$request->string('search').'%');
            })
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::success('Delivery zones retrieved.', DeliveryZoneResource::collection($zones));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:255'],
            'province' => ['nullable', 'string', 'max:255'],
            'base_fee' => ['required', 'numeric', 'min:0'],
            'included_km' => ['required', 'numeric', 'min:0'],
            'extra_fee_per_km' => ['required', 'numeric', 'min:0'],
            'status' => ['nullable', 'string', 'in:ACTIVE,INACTIVE,SUSPENDED'],
        ]);

        $zone = DeliveryZone::create($validated);

        return ApiResponse::success('Delivery zone created.', new DeliveryZoneResource($zone), 201);
    }

    public function show(DeliveryZone $deliveryZone): JsonResponse
    {
        return ApiResponse::success('Delivery zone retrieved.', new DeliveryZoneResource($deliveryZone));
    }

    public function update(Request $request, DeliveryZone $deliveryZone): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:255'],
            'province' => ['nullable', 'string', 'max:255'],
            'base_fee' => ['sometimes', 'numeric', 'min:0'],
            'included_km' => ['sometimes', 'numeric', 'min:0'],
            'extra_fee_per_km' => ['sometimes', 'numeric', 'min:0'],
            'status' => ['sometimes', 'string', 'in:ACTIVE,INACTIVE,SUSPENDED'],
        ]);

        $deliveryZone->update($validated);

        return ApiResponse::success('Delivery zone updated.', new DeliveryZoneResource($deliveryZone->fresh()));
    }

    public function destroy(DeliveryZone $deliveryZone): JsonResponse
    {
        $deliveryZone->delete();

        return ApiResponse::success('Delivery zone deleted.');
    }
}
