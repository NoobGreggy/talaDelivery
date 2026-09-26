<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

class RoadDistanceService
{
    public function distanceKm(float $fromLat, float $fromLng, float $toLat, float $toLng): ?float
    {
        $baseUrl = config('services.routing.base_url');
        if (! is_string($baseUrl) || trim($baseUrl) === '') {
            return null;
        }

        $coordinates = "{$fromLng},{$fromLat};{$toLng},{$toLat}";

        try {
            $response = Http::baseUrl(rtrim($baseUrl, '/'))
                ->connectTimeout((int) config('services.routing.connect_timeout', 2))
                ->timeout((int) config('services.routing.timeout', 5))
                ->get("/route/v1/driving/{$coordinates}", [
                    'overview' => 'false',
                    'alternatives' => 'false',
                ]);
        } catch (ConnectionException) {
            return null;
        }

        if (! $response->successful() || $response->json('code') !== 'Ok') {
            return null;
        }

        $distanceMeters = $response->json('routes.0.distance');

        return is_numeric($distanceMeters) ? (float) $distanceMeters / 1000 : null;
    }
}
