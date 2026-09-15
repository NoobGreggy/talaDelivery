<?php

namespace App\Http\Controllers\Customer;

use App\Http\Controllers\Controller;
use App\Http\Resources\AddressResource;
use App\Models\Address;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AddressController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $addresses = $request->user()->addresses()->latest()->get();

        return ApiResponse::success('Addresses retrieved.', AddressResource::collection($addresses));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $this->validateAddress($request);

        $address = DB::transaction(function () use ($request, $validated) {
            if (! empty($validated['is_default'])) {
                $request->user()->addresses()->update(['is_default' => false]);
            }

            return $request->user()->addresses()->create($validated);
        });

        return ApiResponse::success('Address created.', new AddressResource($address), 201);
    }

    public function show(Request $request, Address $address): JsonResponse
    {
        $this->authorizeOwnership($request, $address);

        return ApiResponse::success('Address retrieved.', new AddressResource($address));
    }

    public function update(Request $request, Address $address): JsonResponse
    {
        $this->authorizeOwnership($request, $address);

        $validated = $this->validateAddress($request);

        DB::transaction(function () use ($request, $address, $validated) {
            if (! empty($validated['is_default'])) {
                $request->user()->addresses()->whereKeyNot($address->id)->update(['is_default' => false]);
            }

            $address->update($validated);
        });

        return ApiResponse::success('Address updated.', new AddressResource($address->fresh()));
    }

    public function destroy(Request $request, Address $address): JsonResponse
    {
        $this->authorizeOwnership($request, $address);

        $address->delete();

        return ApiResponse::success('Address deleted.');
    }

    /**
     * @return array<string, mixed>
     */
    private function validateAddress(Request $request): array
    {
        return $request->validate([
            'label' => ['nullable', 'string', 'max:255'],
            'recipient_name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:20'],
            'address_line' => ['required', 'string', 'max:255'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'province' => ['required', 'string', 'max:255'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'notes' => ['nullable', 'string'],
            'is_default' => ['sometimes', 'boolean'],
        ]);
    }

    private function authorizeOwnership(Request $request, Address $address): void
    {
        if ($address->user_id !== $request->user()->id) {
            abort(403, 'You are not allowed to access this address.');
        }
    }
}
