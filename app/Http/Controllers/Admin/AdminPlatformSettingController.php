<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\PlatformSettingResource;
use App\Models\PlatformSetting;
use App\Support\ApiResponse;
use DateTimeZone;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AdminPlatformSettingController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(
            'Platform settings retrieved.',
            new PlatformSettingResource(PlatformSetting::current()),
        );
    }

    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'rider_commission_type' => ['required', Rule::in(['PERCENTAGE', 'FIXED'])],
            'rider_commission_value' => ['required', 'numeric', 'min:0'],
            'earnings_week_type' => ['required', Rule::in(['ROLLING_SEVEN_DAYS', 'CALENDAR_WEEK'])],
            'week_starts_on' => ['required', 'integer', 'between:0,6'],
            'settlement_timezone' => ['required', 'string', Rule::in(DateTimeZone::listIdentifiers())],
            'settlement_day_starts_at' => ['required', 'date_format:H:i'],
            'distance_method' => ['required', Rule::in(['STRAIGHT_LINE'])],
        ]);

        if ($validated['rider_commission_type'] === 'PERCENTAGE' && (float) $validated['rider_commission_value'] > 100) {
            return ApiResponse::error('Percentage commission cannot exceed 100%.', [
                'rider_commission_value' => ['Percentage commission cannot exceed 100%.'],
            ], 422);
        }

        $settings = PlatformSetting::current();
        $settings->update($validated);

        return ApiResponse::success(
            'Platform settings updated.',
            new PlatformSettingResource($settings->fresh()),
        );
    }
}
