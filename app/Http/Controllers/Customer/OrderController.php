<?php

namespace App\Http\Controllers\Customer;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function __construct(public OrderService $orders) {}

    public function index(Request $request): JsonResponse
    {
        $orders = $request->user()->ordersAsCustomer()
            ->with(['store', 'delivery', 'items'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::success('Orders retrieved.', OrderResource::collection($orders));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'store_id' => ['required', 'integer', 'exists:stores,id'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'customer_name' => ['nullable', 'string', 'max:255'],
            'customer_phone' => ['nullable', 'string', 'max:20'],
            'delivery_address' => ['required', 'string'],
            'delivery_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'delivery_longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'city' => ['nullable', 'string', 'max:255'],
            'province' => ['nullable', 'string', 'max:255'],
            'payment_method' => ['nullable', 'string', 'in:COD,GCASH,MAYA,CARD'],
            'discount' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        try {
            $order = $this->orders->create($validated, $request->user());
        } catch (\DomainException $e) {
            return ApiResponse::error($e->getMessage(), null, 422);
        }

        return ApiResponse::success('Order created successfully.', new OrderResource($order), 201);
    }

    public function show(Request $request, Order $order): JsonResponse
    {
        $this->authorizeOrder($request, $order);

        $order->load(['store', 'items', 'delivery.rider', 'delivery.offers']);

        return ApiResponse::success('Order retrieved.', new OrderResource($order));
    }

    public function cancel(Request $request, Order $order): JsonResponse
    {
        $this->authorizeOrder($request, $order);

        if ($order->status !== OrderStatus::Pending) {
            return ApiResponse::error('Only pending orders can be cancelled.', null, 422);
        }

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        try {
            $order = $this->orders->cancel($order, 'customer', $validated['reason'] ?? null);
        } catch (\DomainException $e) {
            return ApiResponse::error($e->getMessage(), null, 422);
        }

        return ApiResponse::success('Order cancelled.', new OrderResource($order));
    }

    private function authorizeOrder(Request $request, Order $order): void
    {
        if ($order->customer_id !== $request->user()->id) {
            abort(403, 'You are not allowed to access this order.');
        }
    }
}
