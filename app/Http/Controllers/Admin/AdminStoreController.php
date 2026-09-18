<?php

namespace App\Http\Controllers\Admin;

use App\Enums\Role;
use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\StoreResource;
use App\Models\Store;
use App\Models\StoreUser;
use App\Models\User;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AdminStoreController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $stores = Store::query()
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('search'), function ($query) use ($request): void {
                $query->where('name', 'like', '%'.$request->string('search').'%');
            })
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        return ApiResponse::paginated('Stores retrieved.', StoreResource::collection($stores));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'phone' => ['nullable', 'string', 'max:20'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'opening_time' => ['nullable', 'date_format:H:i'],
            'closing_time' => ['nullable', 'date_format:H:i'],
            'status' => ['nullable', 'string', 'in:ACTIVE,INACTIVE,SUSPENDED'],
            'merchant_name' => ['required', 'string', 'max:255'],
            'merchant_email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'merchant_password' => ['required', 'string', 'min:8'],
            'merchant_phone' => ['nullable', 'string', 'max:20'],
        ]);

        $store = DB::transaction(function () use ($validated): Store {
            $created = Store::create([
                'name' => $validated['name'],
                'description' => $validated['description'] ?? null,
                'phone' => $validated['phone'] ?? null,
                'email' => $validated['email'] ?? null,
                'address' => $validated['address'],
                'latitude' => $validated['latitude'] ?? null,
                'longitude' => $validated['longitude'] ?? null,
                'opening_time' => $validated['opening_time'] ?? null,
                'closing_time' => $validated['closing_time'] ?? null,
                'status' => $validated['status'] ?? 'ACTIVE',
                'slug' => $this->uniqueSlug($validated['name']),
            ]);

            $owner = User::query()->create([
                'name' => $validated['merchant_name'],
                'email' => $validated['merchant_email'],
                'phone' => $validated['merchant_phone'] ?? null,
                'password' => $validated['merchant_password'],
                'role' => Role::StoreAdmin->value,
                'status' => UserStatus::Active,
            ]);

            $owner->assignRole(Role::StoreAdmin->value);

            StoreUser::query()->create([
                'store_id' => $created->id,
                'user_id' => $owner->id,
                'role' => Role::StoreAdmin->value,
            ]);

            return $created;
        });

        return ApiResponse::success('Store and merchant account created.', new StoreResource($store), 201);
    }

    public function show(Store $store): JsonResponse
    {
        return ApiResponse::success('Store retrieved.', new StoreResource($store->load('categories')));
    }

    public function update(Request $request, Store $store): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'phone' => ['nullable', 'string', 'max:20'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['sometimes', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'opening_time' => ['nullable', 'date_format:H:i'],
            'closing_time' => ['nullable', 'date_format:H:i'],
            'status' => ['sometimes', 'string', 'in:ACTIVE,INACTIVE,SUSPENDED'],
        ]);

        $store->update($validated);

        return ApiResponse::success('Store updated.', new StoreResource($store->fresh()));
    }

    private function uniqueSlug(string $name): string
    {
        $base = Str::slug($name);
        $slug = $base;
        $suffix = 1;

        while (Store::where('slug', $slug)->exists()) {
            $slug = $base.'-'.$suffix;
            $suffix++;
        }

        return $slug;
    }
}
