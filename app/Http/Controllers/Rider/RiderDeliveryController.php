<?php

namespace App\Http\Controllers\Rider;

use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryResource;
use App\Models\Delivery;
use App\Services\DeliveryService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RiderDeliveryController extends Controller
{
    public function __construct(public DeliveryService $deliveries) {}

    public function arrived(Request $request, Delivery $delivery): JsonResponse
    {
        return $this->run(fn () => $this->deliveries->arrived($delivery, $request->user()), 'Arrival recorded.');
    }

    public function pickup(Request $request, Delivery $delivery): JsonResponse
    {
        return $this->run(fn () => $this->deliveries->pickup($delivery, $request->user()), 'Order picked up.');
    }

    public function start(Request $request, Delivery $delivery): JsonResponse
    {
        return $this->run(fn () => $this->deliveries->start($delivery, $request->user()), 'Delivery started.');
    }

    public function complete(Request $request, Delivery $delivery): JsonResponse
    {
        return $this->run(fn () => $this->deliveries->complete($delivery, $request->user()), 'Delivery completed.');
    }

    private function run(callable $callback, string $message): JsonResponse
    {
        try {
            $delivery = $callback();
        } catch (\DomainException $e) {
            return ApiResponse::error($e->getMessage(), null, 422);
        }

        return ApiResponse::success($message, new DeliveryResource($delivery->load('order', 'rider')));
    }
}
