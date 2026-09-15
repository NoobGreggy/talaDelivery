<?php

namespace App\Http\Middleware;

use App\Models\Store;
use App\Models\StoreUser;
use App\Support\ApiResponse;
use App\Support\StoreContext;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ResolveStoreTenant
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $storeKey = $request->header('X-Store-Id');

        if (! is_numeric($storeKey)) {
            return ApiResponse::error('X-Store-Id header is required.', null, 403);
        }

        $store = Store::find((int) $storeKey);

        if (! $store) {
            return ApiResponse::error('Store not found for the provided X-Store-Id.', null, 404);
        }

        $user = $request->user();

        if ($user && ! $user->hasRole('platform_admin')) {
            $membership = StoreUser::where('store_id', $store->id)
                ->where('user_id', $user->id)
                ->exists();

            if (! $membership) {
                return ApiResponse::error('You do not belong to this store.', null, 403);
            }
        }

        StoreContext::setStore($store);
        StoreContext::setUserId($user?->id);

        return $next($request);
    }
}
