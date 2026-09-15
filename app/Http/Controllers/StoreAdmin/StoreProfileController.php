<?php

namespace App\Http\Controllers\StoreAdmin;

use App\Http\Controllers\Controller;
use App\Http\Resources\StoreResource;
use App\Support\ApiResponse;
use App\Support\StoreContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StoreProfileController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success('Store profile retrieved.', new StoreResource(StoreContext::store()));
    }

    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'phone' => ['nullable', 'string', 'max:20'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'opening_time' => ['nullable', 'date_format:H:i'],
            'closing_time' => ['nullable', 'date_format:H:i'],
            'status' => ['sometimes', 'string', 'in:ACTIVE,INACTIVE,SUSPENDED'],
        ]);

        $store = StoreContext::store();
        $store->update($validated);

        return ApiResponse::success('Store profile updated.', new StoreResource($store->fresh()));
    }
}
