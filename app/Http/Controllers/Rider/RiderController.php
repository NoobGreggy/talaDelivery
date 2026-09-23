<?php

namespace App\Http\Controllers\Rider;

use App\Enums\DeliveryOfferStatus;
use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryResource;
use App\Http\Resources\RiderResource;
use App\Http\Resources\UserResource;
use App\Jobs\MatchRider;
use App\Models\Delivery;
use App\Models\Rider;
use App\Models\User;
use App\Services\RiderEarningsService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RiderController extends Controller
{
    public function __construct(public RiderEarningsService $earnings) {}

    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:20'],
            'password' => ['required', 'string', 'min:8'],
            'vehicle_type' => ['required', 'string', 'in:MOTORCYCLE,BICYCLE,CAR'],
            'vehicle_plate' => ['nullable', 'string', 'max:20'],
            'license_number' => ['nullable', 'string', 'max:50'],
            'requirements' => ['nullable', 'array'],
        ]);

        $user = User::query()->create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'password' => $validated['password'],
            'role' => Role::Rider->value,
            'status' => UserStatus::Active,
        ]);

        $user->assignRole(Role::Rider->value);

        $user->rider()->create([
            'vehicle_type' => $validated['vehicle_type'],
            'vehicle_plate' => $validated['vehicle_plate'] ?? null,
            'license_number' => $validated['license_number'] ?? null,
            'requirements' => $validated['requirements'] ?? null,
            'is_online' => false,
            'status' => RiderStatus::Pending,
        ]);

        $token = $user->createToken('auth-token')->plainTextToken;

        return ApiResponse::success('Rider application submitted. Please wait for admin approval.', [
            'token' => $token,
            'user' => new UserResource($user->load('rider')),
        ], 201);
    }

    public function profile(Request $request): JsonResponse
    {
        $rider = $request->user()->rider;

        if (! $rider) {
            return ApiResponse::error('Rider profile not found.', null, 404);
        }

        return ApiResponse::success('Rider profile retrieved.', new RiderResource($this->profileData($rider)));
    }

    public function online(Request $request): JsonResponse
    {
        $rider = $this->rider($request);

        if ($rider->status === RiderStatus::Pending) {
            return ApiResponse::error('Your application is still pending admin approval.', null, 403);
        }

        if ($rider->status === RiderStatus::Rejected) {
            return ApiResponse::error('Your application was rejected by the admin.', null, 403);
        }

        if ($rider->status === RiderStatus::Suspended) {
            return ApiResponse::error('Suspended riders cannot go online.', null, 403);
        }

        $rider->update(['is_online' => true, 'status' => RiderStatus::Online]);

        if ($rider->current_latitude !== null && $rider->current_longitude !== null) {
            $this->retryUnmatchedDeliveries();
        }

        return ApiResponse::success('You are now online.', new RiderResource($this->profileData($rider->fresh())));
    }

    public function offline(Request $request): JsonResponse
    {
        $rider = $this->rider($request);

        if ($rider->status === RiderStatus::Busy) {
            return ApiResponse::error('You cannot go offline while delivering an order.', null, 422);
        }

        $rider->update(['is_online' => false, 'status' => RiderStatus::Offline]);

        return ApiResponse::success('You are now offline.', new RiderResource($this->profileData($rider->fresh())));
    }

    public function location(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $rider = $this->rider($request);
        $hadLocation = $rider->current_latitude !== null && $rider->current_longitude !== null;
        $rider->update([
            'current_latitude' => $validated['latitude'],
            'current_longitude' => $validated['longitude'],
        ]);

        if (! $hadLocation && $rider->status === RiderStatus::Online) {
            $this->retryUnmatchedDeliveries();
        }

        return ApiResponse::success('Location updated.', new RiderResource($this->profileData($rider->fresh())));
    }

    public function deliveries(Request $request): JsonResponse
    {
        $deliveries = $request->user()->deliveriesAsRider()
            ->with(['order.items', 'store'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Deliveries retrieved.', DeliveryResource::collection($deliveries));
    }

    public function earningsSummary(Request $request): JsonResponse
    {
        return ApiResponse::success(
            'Rider earnings summary retrieved.',
            $this->earnings->summary($request->user()),
        );
    }

    private function profileData(Rider $rider): Rider
    {
        return $rider->load(['user', 'currentDelivery'])
            ->loadCount(['deliveries as completed_deliveries' => fn ($query) => $query->where('status', DeliveryStatus::Delivered)])
            ->loadSum(['deliveries as total_earnings' => fn ($query) => $query->where('status', DeliveryStatus::Delivered)], 'rider_commission');
    }

    private function rider(Request $request): Rider
    {
        $rider = $request->user()->rider;

        abort_if($rider === null, 404, 'Rider profile not found.');

        return $rider;
    }

    private function retryUnmatchedDeliveries(): void
    {
        Delivery::query()
            ->where('status', DeliveryStatus::Unassigned)
            ->whereNull('rider_id')
            ->whereHas('order', fn ($query) => $query->where('status', OrderStatus::ReadyForPickup))
            ->whereDoesntHave('offers', fn ($query) => $query->where('status', DeliveryOfferStatus::Pending))
            ->each(fn (Delivery $delivery) => MatchRider::dispatch($delivery));
    }
}
