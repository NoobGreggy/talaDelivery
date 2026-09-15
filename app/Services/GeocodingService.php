<?php

namespace App\Services;

use App\Models\Address;

class GeocodingService
{
    /**
     * Resolve coordinates for an address.
     *
     * MVP has no external geocoding provider configured, so coordinates are only
     * returned when they were supplied by the client. Swapping in a provider later
     * only requires changing this method.
     *
     * @return array{latitude: float|null, longitude: float|null}
     */
    public function coordinates(Address $address): array
    {
        return [
            'latitude' => $address->latitude,
            'longitude' => $address->longitude,
        ];
    }
}
