<?php

namespace App\Http\Controllers\StoreAdmin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Support\ApiResponse;
use App\Support\StoreContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StoreProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $products = Product::where('store_id', StoreContext::storeId())
            ->when($request->filled('category_id'), fn ($query) => $query->where('category_id', $request->integer('category_id')))
            ->when($request->filled('search'), fn ($query) => $query->where('name', 'like', '%'.$request->string('search').'%'))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::success('Products retrieved.', ProductResource::collection($products));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category_id' => [
                'nullable',
                Rule::exists('categories', 'id')->where('store_id', StoreContext::storeId()),
            ],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'sku' => ['nullable', 'string', 'max:255'],
            'price' => ['required', 'numeric', 'min:0'],
            'image' => ['nullable', 'string', 'max:2048'],
            'stock' => ['nullable', 'integer', 'min:0'],
            'is_available' => ['sometimes', 'boolean'],
        ]);

        $product = Product::create([
            ...$validated,
            'store_id' => StoreContext::storeId(),
        ]);

        return ApiResponse::success('Product created.', new ProductResource($product), 201);
    }

    public function show(Product $product): JsonResponse
    {
        $this->authorizeProduct($product);

        return ApiResponse::success('Product retrieved.', new ProductResource($product));
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $this->authorizeProduct($product);

        $validated = $request->validate([
            'category_id' => [
                'nullable',
                Rule::exists('categories', 'id')->where('store_id', StoreContext::storeId()),
            ],
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'sku' => ['nullable', 'string', 'max:255'],
            'price' => ['sometimes', 'numeric', 'min:0'],
            'image' => ['nullable', 'string', 'max:2048'],
            'stock' => ['sometimes', 'integer', 'min:0'],
            'is_available' => ['sometimes', 'boolean'],
        ]);

        $product->update($validated);

        return ApiResponse::success('Product updated.', new ProductResource($product->fresh()));
    }

    public function destroy(Product $product): JsonResponse
    {
        $this->authorizeProduct($product);

        $product->delete();

        return ApiResponse::success('Product deleted.');
    }

    private function authorizeProduct(Product $product): void
    {
        if ($product->store_id !== StoreContext::storeId()) {
            abort(404, 'Product not found.');
        }
    }
}
