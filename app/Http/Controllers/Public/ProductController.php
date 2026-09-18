<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $products = Product::query()
            ->where('is_available', true)
            ->whereHas('store', fn ($query) => $query->where('status', 'ACTIVE'))
            ->when($request->filled('store_id'), fn ($query) => $query->where('store_id', $request->integer('store_id')))
            ->when($request->filled('category_id'), fn ($query) => $query->where('category_id', $request->integer('category_id')))
            ->when($request->filled('search'), fn ($query) => $query->where('name', 'like', '%'.$request->string('search').'%'))
            ->when($request->filled('min_price'), fn ($query) => $query->where('price', '>=', $request->float('min_price')))
            ->when($request->filled('max_price'), fn ($query) => $query->where('price', '<=', $request->float('max_price')))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Products retrieved.', ProductResource::collection($products));
    }

    public function show(Product $product): JsonResponse
    {
        $product->load('store', 'category');

        return ApiResponse::success('Product retrieved.', new ProductResource($product));
    }
}
