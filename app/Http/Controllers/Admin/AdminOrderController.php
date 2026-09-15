<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminOrderController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $orders = Order::query()
            ->with(['store', 'customer', 'delivery.rider'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('store_id'), fn ($query) => $query->where('store_id', $request->integer('store_id')))
            ->when($request->filled('search'), function ($query) use ($request): void {
                $query->where('order_number', 'like', '%'.$request->string('search').'%');
            })
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::success('Orders retrieved.', OrderResource::collection($orders));
    }

    public function show(Order $order): JsonResponse
    {
        $order->load(['store', 'customer', 'items', 'delivery.rider']);

        return ApiResponse::success('Order retrieved.', new OrderResource($order));
    }
}
