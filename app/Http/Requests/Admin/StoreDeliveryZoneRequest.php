<?php

namespace App\Http\Requests\Admin;

use App\Enums\DeliveryZoneStatus;
use App\Rules\ValidGeoJsonPolygon;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class StoreDeliveryZoneRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $status = $this->input('status', DeliveryZoneStatus::Active->value);
        $this->merge([
            'distance_rounding_km' => $this->input('distance_rounding_km', 0.1),
            'status' => $status === 'INACTIVE' ? DeliveryZoneStatus::Archived->value : $status,
        ]);
    }

    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'province' => ['required', 'string', 'max:255'],
            'boundary_geojson' => ['nullable', 'array', new ValidGeoJsonPolygon],
            'base_fee' => ['required', 'numeric', 'min:0'],
            'included_km' => ['required', 'numeric', 'min:0'],
            'maximum_delivery_km' => ['nullable', 'numeric', 'gt:0'],
            'extra_fee_per_km' => ['required', 'numeric', 'min:0'],
            'maximum_delivery_fee' => ['nullable', 'numeric', 'min:0'],
            'distance_rounding_km' => ['required', 'numeric', 'between:0.1,5'],
            'effective_from' => ['nullable', 'date'],
            'status' => ['required', Rule::enum(DeliveryZoneStatus::class)],
        ];
    }

    /** @return array<int, callable(Validator): void> */
    public function after(): array
    {
        return [fn (Validator $validator) => $this->validatePricingBounds($validator)];
    }

    private function validatePricingBounds(Validator $validator): void
    {
        if ($this->filled('maximum_delivery_km') && $this->float('maximum_delivery_km') < $this->float('included_km')) {
            $validator->errors()->add('maximum_delivery_km', 'Maximum distance must be greater than or equal to the included distance.');
        }

        if ($this->filled('maximum_delivery_fee') && $this->float('maximum_delivery_fee') < $this->float('base_fee')) {
            $validator->errors()->add('maximum_delivery_fee', 'Maximum fee must be greater than or equal to the base fee.');
        }
    }
}
