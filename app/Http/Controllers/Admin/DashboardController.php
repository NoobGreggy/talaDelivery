<?php

namespace App\Http\Controllers\Admin;

use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\Rider;
use App\Models\Store;
use App\Models\User;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function index(): JsonResponse
    {
        return ApiResponse::success('Dashboard retrieved.', [
            'totals' => [
                'stores' => Store::count(),
                'riders' => Rider::count(),
                'customers' => User::query()->where('role', Role::Customer->value)->count(),
                'orders' => Order::count(),
                'deliveries' => Delivery::count(),
                'pending_orders' => Order::query()->where('status', OrderStatus::Pending)->count(),
                'online_riders' => Rider::query()->where('status', RiderStatus::Online)->count(),
            ],
            'today' => [
                'orders' => Order::query()->whereDate('created_at', today())->count(),
                'delivered' => Delivery::query()
                    ->where('status', DeliveryStatus::Delivered)
                    ->whereDate('delivered_at', today())
                    ->count(),
                'revenue' => Order::query()
                    ->where('status', OrderStatus::Delivered)
                    ->whereDate('delivered_at', today())
                    ->sum('total'),
            ],
        ]);
    }
}
