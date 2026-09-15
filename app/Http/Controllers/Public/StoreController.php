<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\ProductResource;
use App\Http\Resources\StoreResource;
use App\Models\Store;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StoreController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $stores = Store::query()
            ->where('status', 'ACTIVE')
            ->when($request->filled('search'), function ($query) use ($request): void {
                $search = $request->string('search')->trim()->toString();
                $query->where(function ($query) use ($search): void {
                    $query->whereLike('name', "%{$search}%")
                        ->orWhereLike('description', "%{$search}%");
                });
            })
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::success('Stores retrieved.', StoreResource::collection($stores));
    }

    public function show(Store $store): JsonResponse
    {
        $store->load(['categories', 'products' => fn ($query) => $query->where('is_available', true)]);

        return ApiResponse::success('Store retrieved.', new StoreResource($store));
    }

    public function categories(Store $store): JsonResponse
    {
        $categories = $store->categories()->where('status', 'ACTIVE')->get();

        return ApiResponse::success('Categories retrieved.', CategoryResource::collection($categories));
    }

    public function products(Request $request, Store $store): JsonResponse
    {
        $products = $store->products()
            ->where('is_available', true)
            ->when($request->filled('category_id'), fn ($query) => $query->where('category_id', $request->integer('category_id')))
            ->when($request->filled('search'), fn ($query) => $query->where('name', 'like', '%'.$request->string('search').'%'))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::success('Products retrieved.', ProductResource::collection($products));
    }
}
