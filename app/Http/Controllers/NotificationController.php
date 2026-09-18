<?php

namespace App\Http\Controllers;

use App\Http\Resources\NotificationResource;
use App\Models\Notification;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $notifications = $request->user()->notifications()
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Notifications retrieved.', NotificationResource::collection($notifications));
    }

    public function show(Request $request, Notification $notification): JsonResponse
    {
        $this->authorizeOwnership($request, $notification);

        return ApiResponse::success('Notification retrieved.', new NotificationResource($notification));
    }

    public function markAsRead(Request $request, Notification $notification): JsonResponse
    {
        $this->authorizeOwnership($request, $notification);

        $notification->markAsRead();

        return ApiResponse::success('Notification marked as read.', new NotificationResource($notification->fresh()));
    }

    private function authorizeOwnership(Request $request, Notification $notification): void
    {
        if ($notification->user_id !== $request->user()->id) {
            abort(404, 'Notification not found.');
        }
    }
}
