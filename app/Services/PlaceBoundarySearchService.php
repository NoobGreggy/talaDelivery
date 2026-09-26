<?php

namespace App\Services;

use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class PlaceBoundarySearchService
{
    /**
     * @return array<int, array<string, mixed>>
     */
    public function search(string $query, string $type): array
    {
        $normalizedQuery = Str::of($query)->squish()->lower()->toString();
        $cacheKey = 'place-boundary:'.$type.':'.sha1($normalizedQuery);

        return Cache::remember(
            $cacheKey,
            now()->addDays((int) config('services.geocoding.cache_days', 30)),
            fn (): array => $this->request($query, $type),
        );
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function request(string $query, string $type): array
    {
        $baseUrl = rtrim((string) config('services.geocoding.base_url'), '/');
        if ($baseUrl === '') {
            throw new \DomainException('Boundary search is not configured.');
        }

        try {
            $response = Http::baseUrl($baseUrl)
                ->acceptJson()
                ->withUserAgent((string) config('services.geocoding.user_agent'))
                ->connectTimeout((int) config('services.geocoding.connect_timeout', 3))
                ->timeout((int) config('services.geocoding.timeout', 15))
                ->get('/search', [
                    'q' => $query,
                    'format' => 'jsonv2',
                    'addressdetails' => 1,
                    'polygon_geojson' => 1,
                    'polygon_threshold' => 0.0005,
                    'countrycodes' => 'ph',
                    'featureType' => $type === 'province' ? 'state' : 'city',
                    'limit' => 5,
                ]);
        } catch (\Throwable) {
            throw new \DomainException('The boundary search service is temporarily unavailable.');
        }

        if (! $response->successful() || ! is_array($response->json())) {
            throw new \DomainException('The boundary search service is temporarily unavailable.');
        }

        return collect($response->json())
            ->filter(fn (mixed $result): bool => is_array($result)
                && in_array(Arr::get($result, 'geojson.type'), ['Polygon', 'MultiPolygon'], true))
            ->map(fn (array $result): array => $this->normalizeResult($result))
            ->values()
            ->all();
    }

    /**
     * @param  array<string, mixed>  $result
     * @return array<string, mixed>
     */
    private function normalizeResult(array $result): array
    {
        $address = is_array($result['address'] ?? null) ? $result['address'] : [];

        return [
            'place_id' => (string) ($result['place_id'] ?? ''),
            'name' => (string) ($result['name'] ?? $result['display_name'] ?? ''),
            'display_name' => (string) ($result['display_name'] ?? ''),
            'type' => (string) ($result['addresstype'] ?? $result['type'] ?? 'administrative'),
            'city' => $this->firstAddressValue($address, ['city', 'municipality', 'town', 'city_district', 'county']),
            'province' => $this->firstAddressValue($address, ['state', 'region', 'province']),
            'geometry' => $result['geojson'],
            'bounding_box' => array_map('floatval', (array) ($result['boundingbox'] ?? [])),
        ];
    }

    /** @param array<string, mixed> $address */
    private function firstAddressValue(array $address, array $keys): ?string
    {
        foreach ($keys as $key) {
            $value = $address[$key] ?? null;
            if (is_string($value) && $value !== '') {
                return $value;
            }
        }

        return null;
    }
}
