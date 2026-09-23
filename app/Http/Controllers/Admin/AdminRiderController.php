<?php

namespace App\Http\Controllers\Admin;

use App\Enums\DeliveryStatus;
use App\Enums\RiderStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\RiderResource;
use App\Models\Rider;
use App\Services\NotificationService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminRiderController extends Controller
{
    public function __construct(public NotificationService $notifications) {}

    public function index(Request $request): JsonResponse
    {
        $riders = Rider::query()
            ->with(['user', 'currentDelivery'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Riders retrieved.', RiderResource::collection($riders));
    }

    public function show(Rider $rider): JsonResponse
    {
        $rider->load('user', 'currentDelivery')
            ->loadCount(['deliveries as completed_deliveries' => fn ($query) => $query->where('status', DeliveryStatus::Delivered)])
            ->loadSum(['deliveries as total_earnings' => fn ($query) => $query->where('status', DeliveryStatus::Delivered)], 'rider_commission');

        return ApiResponse::success('Rider retrieved.', new RiderResource($rider));
    }

    public function approve(Rider $rider): JsonResponse
    {
        return $this->setApprovalStatus($rider, RiderStatus::Offline, 'Rider approved.', 'rider.approved', 'Application approved', 'Congratulations! Your rider application has been approved. You can now go online.');
    }

    public function reject(Request $request, Rider $rider): JsonResponse
    {
        $message = $request->string('reason')->toString();

        return $this->setApprovalStatus($rider, RiderStatus::Rejected, 'Rider rejected.', 'rider.rejected', 'Application rejected', $message !== '' ? $message : 'Your rider application was not approved.');
    }

    public function suspend(Request $request, Rider $rider): JsonResponse
    {
        $message = $request->string('reason')->toString();

        return $this->setApprovalStatus($rider, RiderStatus::Suspended, 'Rider suspended.', 'rider.suspended', 'Account suspended', $message !== '' ? $message : 'Your rider account has been suspended.');
    }

    private function setApprovalStatus(Rider $rider, RiderStatus $status, string $responseMessage, string $type, string $title, string $notificationMessage): JsonResponse
    {
        $rider->update(['status' => $status]);

        $this->notifications->notify(
            $rider->user_id,
            $type,
            $title,
            $notificationMessage,
            ['rider_id' => $rider->id],
        );

        return ApiResponse::success($responseMessage, new RiderResource($rider->fresh('user')));
    }
}
