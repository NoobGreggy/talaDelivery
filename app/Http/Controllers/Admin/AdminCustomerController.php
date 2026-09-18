<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OrderStatus;
use App\Enums\Role;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminCustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $customers = User::query()
            ->where('role', Role::Customer->value)
            ->withCount('ordersAsCustomer as orders_count')
            ->withSum([
                'ordersAsCustomer as total_spent' => fn ($query) => $query->where('status', OrderStatus::Delivered),
            ], 'total')
            ->when($request->filled('search'), function ($query) use ($request): void {
                $search = $request->string('search');
                $query->where(function ($query) use ($search): void {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Customers retrieved.', UserResource::collection($customers));
    }
}
