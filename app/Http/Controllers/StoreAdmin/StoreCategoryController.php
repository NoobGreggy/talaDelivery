<?php

namespace App\Http\Controllers\StoreAdmin;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use App\Support\ApiResponse;
use App\Support\StoreContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StoreCategoryController extends Controller
{
    public function index(): JsonResponse
    {
        $categories = Category::where('store_id', StoreContext::storeId())->latest()->get();

        return ApiResponse::success('Categories retrieved.', CategoryResource::collection($categories));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'status' => ['nullable', 'string', 'in:ACTIVE,INACTIVE,SUSPENDED'],
        ]);

        $category = Category::create([
            ...$validated,
            'store_id' => StoreContext::storeId(),
        ]);

        return ApiResponse::success('Category created.', new CategoryResource($category), 201);
    }

    public function show(Category $category): JsonResponse
    {
        $this->authorizeCategory($category);

        return ApiResponse::success('Category retrieved.', new CategoryResource($category));
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $this->authorizeCategory($category);

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'status' => ['sometimes', 'string', 'in:ACTIVE,INACTIVE,SUSPENDED'],
        ]);

        $category->update($validated);

        return ApiResponse::success('Category updated.', new CategoryResource($category->fresh()));
    }

    public function destroy(Category $category): JsonResponse
    {
        $this->authorizeCategory($category);

        $category->delete();

        return ApiResponse::success('Category deleted.');
    }

    private function authorizeCategory(Category $category): void
    {
        if ($category->store_id !== StoreContext::storeId()) {
            abort(404, 'Category not found.');
        }
    }
}
