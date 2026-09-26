<?php

namespace App\Http\Requests\Admin;

use App\Rules\ValidGeoJsonBoundary;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PreviewDeliveryZonePricingRequest extends FormRequest
{
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
            'zone' => ['required', 'array'],
            'zone.boundary_geojson' => ['nullable', 'array', new ValidGeoJsonBoundary],
            'zone.base_fee' => ['required', 'numeric', 'min:0'],
            'zone.included_km' => ['required', 'numeric', 'min:0'],
            'zone.maximum_delivery_km' => ['nullable', 'numeric', 'gt:0'],
            'zone.extra_fee_per_km' => ['required', 'numeric', 'min:0'],
            'zone.maximum_delivery_fee' => ['nullable', 'numeric', 'min:0'],
            'zone.distance_rounding_km' => ['required', 'numeric', 'between:0.1,5'],
            'pickup_latitude' => ['required', 'numeric', 'between:-90,90'],
            'pickup_longitude' => ['required', 'numeric', 'between:-180,180'],
            'delivery_latitude' => ['required', 'numeric', 'between:-90,90'],
            'delivery_longitude' => ['required', 'numeric', 'between:-180,180'],
            'distance_method' => ['nullable', Rule::in(['STRAIGHT_LINE', 'ROAD_ROUTE'])],
        ];
    }
}
