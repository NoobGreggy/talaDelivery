<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreDeliveryZoneRequest;
use App\Http\Requests\Admin\UpdateDeliveryZoneRequest;
use App\Http\Resources\DeliveryZoneResource;
use App\Models\DeliveryZone;
use App\Services\DeliveryZoneManager;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDeliveryZoneController extends Controller
{
    public function __construct(private DeliveryZoneManager $zones) {}

    public function index(Request $request): JsonResponse
    {
        $zones = DeliveryZone::query()
            ->with('updatedBy:id,name')
            ->withCount('revisions')
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('search'), function ($query) use ($request): void {
                $search = '%'.$request->string('search')->toString().'%';
                $query->where(fn ($nested) => $nested
                    ->where('name', 'like', $search)
                    ->orWhere('city', 'like', $search)
                    ->orWhere('province', 'like', $search));
            })
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Delivery zones retrieved.', DeliveryZoneResource::collection($zones));
    }

    public function store(StoreDeliveryZoneRequest $request): JsonResponse
    {
        $zone = $this->zones->create($request->validated(), $request->user());

        return ApiResponse::success('Delivery zone created.', new DeliveryZoneResource($zone), 201);
    }

    public function show(DeliveryZone $deliveryZone): JsonResponse
    {
        $deliveryZone->load([
            'updatedBy:id,name',
            'revisions' => fn ($query) => $query->with('user:id,name')->latest()->limit(20),
        ])->loadCount('revisions');

        return ApiResponse::success('Delivery zone retrieved.', new DeliveryZoneResource($deliveryZone));
    }

    public function update(UpdateDeliveryZoneRequest $request, DeliveryZone $deliveryZone): JsonResponse
    {
        $zone = $this->zones->update($deliveryZone, $request->validated(), $request->user());

        return ApiResponse::success('Delivery zone updated.', new DeliveryZoneResource($zone));
    }

    public function destroy(Request $request, DeliveryZone $deliveryZone): JsonResponse
    {
        $zone = $this->zones->archive($deliveryZone, $request->user());

        return ApiResponse::success('Delivery zone archived.', new DeliveryZoneResource($zone));
    }
}
