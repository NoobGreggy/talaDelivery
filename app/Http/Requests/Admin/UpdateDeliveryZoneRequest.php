<?php

namespace App\Http\Requests\Admin;

use App\Enums\DeliveryZoneStatus;
use App\Models\DeliveryZone;
use App\Rules\ValidGeoJsonPolygon;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class UpdateDeliveryZoneRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if ($this->input('status') === 'INACTIVE') {
            $this->merge(['status' => DeliveryZoneStatus::Archived->value]);
        }
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
            'name' => ['sometimes', 'string', 'max:255'],
            'city' => ['sometimes', 'string', 'max:255'],
            'province' => ['sometimes', 'string', 'max:255'],
            'boundary_geojson' => ['sometimes', 'nullable', 'array', new ValidGeoJsonPolygon],
            'base_fee' => ['sometimes', 'numeric', 'min:0'],
            'included_km' => ['sometimes', 'numeric', 'min:0'],
            'maximum_delivery_km' => ['sometimes', 'nullable', 'numeric', 'gt:0'],
            'extra_fee_per_km' => ['sometimes', 'numeric', 'min:0'],
            'maximum_delivery_fee' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'distance_rounding_km' => ['sometimes', 'numeric', 'between:0.1,5'],
            'effective_from' => ['sometimes', 'nullable', 'date'],
            'status' => ['sometimes', Rule::enum(DeliveryZoneStatus::class)],
        ];
    }

    /** @return array<int, callable(Validator): void> */
    public function after(): array
    {
        return [function (Validator $validator): void {
            $zone = $this->route('deliveryZone');
            if (! $zone instanceof DeliveryZone) {
                return;
            }

            $includedKm = $this->has('included_km') ? $this->float('included_km') : (float) $zone->included_km;
            $maximumKm = $this->has('maximum_delivery_km') ? $this->input('maximum_delivery_km') : $zone->maximum_delivery_km;
            $baseFee = $this->has('base_fee') ? $this->float('base_fee') : (float) $zone->base_fee;
            $maximumFee = $this->has('maximum_delivery_fee') ? $this->input('maximum_delivery_fee') : $zone->maximum_delivery_fee;

            if ($maximumKm !== null && (float) $maximumKm < $includedKm) {
                $validator->errors()->add('maximum_delivery_km', 'Maximum distance must be greater than or equal to the included distance.');
            }

            if ($maximumFee !== null && (float) $maximumFee < $baseFee) {
                $validator->errors()->add('maximum_delivery_fee', 'Maximum fee must be greater than or equal to the base fee.');
            }
        }];
    }
}
