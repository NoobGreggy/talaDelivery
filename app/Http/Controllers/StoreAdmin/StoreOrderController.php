<?php

namespace App\Http\Controllers\StoreAdmin;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use App\Support\ApiResponse;
use App\Support\StoreContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StoreOrderController extends Controller
{
    public function __construct(public OrderService $orders) {}

    public function index(Request $request): JsonResponse
    {
        $orders = Order::where('store_id', StoreContext::storeId())
            ->with(['customer', 'items', 'delivery'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Orders retrieved.', OrderResource::collection($orders));
    }

    public function show(Order $order): JsonResponse
    {
        $this->authorizeOrder($order);
        $order->load(['customer', 'items', 'delivery.rider']);

        return ApiResponse::success('Order retrieved.', new OrderResource($order));
    }

    public function confirm(Order $order): JsonResponse
    {
        return $this->transition($order, fn () => $this->orders->confirm($order));
    }

    public function preparing(Order $order): JsonResponse
    {
        return $this->transition($order, fn () => $this->orders->preparing($order));
    }

    public function ready(Order $order): JsonResponse
    {
        return $this->transition($order, fn () => $this->orders->ready($order));
    }

    public function cancel(Request $request, Order $order): JsonResponse
    {
        $this->authorizeOrder($order);

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        return $this->transition(
            $order,
            fn () => $this->orders->cancel($order, 'store', $validated['reason'] ?? null),
            'Order cancelled.',
        );
    }

    private function transition(Order $order, callable $callback, string $message = 'Order updated.'): JsonResponse
    {
        $this->authorizeOrder($order);

        try {
            $updated = $callback();
        } catch (\DomainException $e) {
            return ApiResponse::error($e->getMessage(), null, 422);
        }

        return ApiResponse::success($message, new OrderResource($updated->load('items', 'delivery')));
    }

    private function authorizeOrder(Order $order): void
    {
        if ($order->store_id !== StoreContext::storeId()) {
            abort(404, 'Order not found.');
        }
    }
}
