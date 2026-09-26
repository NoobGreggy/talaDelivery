<?php

namespace App\Services;

use App\Enums\DeliveryZoneStatus;
use App\Models\DeliveryZone;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class DeliveryZoneManager
{
    public function __construct(private ZoneBoundaryService $boundaries) {}

    /** @param array<string, mixed> $attributes */
    public function create(array $attributes, User $actor): DeliveryZone
    {
        return DB::transaction(function () use ($attributes, $actor): DeliveryZone {
            $attributes = $this->normalize($attributes);
            $attributes['created_by'] = $actor->id;
            $attributes['updated_by'] = $actor->id;
            $this->assertCanPublish($attributes);

            $zone = DeliveryZone::query()->create($attributes);
            $zone->revisions()->create([
                'user_id' => $actor->id,
                'action' => 'CREATED',
                'after' => $this->snapshot($zone),
            ]);

            return $zone->fresh(['updatedBy']);
        });
    }

    /** @param array<string, mixed> $attributes */
    public function update(DeliveryZone $zone, array $attributes, User $actor): DeliveryZone
    {
        return DB::transaction(function () use ($zone, $attributes, $actor): DeliveryZone {
            $before = $this->snapshot($zone);
            $attributes = $this->normalize($attributes);
            $attributes['updated_by'] = $actor->id;
            $candidate = clone $zone;
            $candidate->fill($attributes);
            $this->assertCanPublish($candidate->attributesToArray(), $zone);

            $zone->update($attributes);
            $zone->revisions()->create([
                'user_id' => $actor->id,
                'action' => 'UPDATED',
                'before' => $before,
                'after' => $this->snapshot($zone->fresh()),
            ]);

            return $zone->fresh(['updatedBy']);
        });
    }

    public function archive(DeliveryZone $zone, User $actor): DeliveryZone
    {
        return DB::transaction(function () use ($zone, $actor): DeliveryZone {
            $before = $this->snapshot($zone);
            $zone->update([
                'status' => DeliveryZoneStatus::Archived,
                'updated_by' => $actor->id,
            ]);
            $zone->revisions()->create([
                'user_id' => $actor->id,
                'action' => 'ARCHIVED',
                'before' => $before,
                'after' => $this->snapshot($zone->fresh()),
            ]);

            return $zone->fresh(['updatedBy']);
        });
    }

    /** @param array<string, mixed> $attributes */
    private function normalize(array $attributes): array
    {
        foreach (['name', 'city', 'province'] as $field) {
            if (array_key_exists($field, $attributes) && is_string($attributes[$field])) {
                $attributes[$field] = Str::squish($attributes[$field]);
            }
        }

        return $attributes;
    }

    /** @param array<string, mixed> $attributes */
    private function assertCanPublish(array $attributes, ?DeliveryZone $current = null): void
    {
        $status = $attributes['status'] ?? $current?->status;
        $statusValue = $status instanceof DeliveryZoneStatus ? $status->value : $status;
        if ($statusValue !== DeliveryZoneStatus::Active->value) {
            return;
        }

        $city = (string) ($attributes['city'] ?? $current?->city ?? '');
        $province = (string) ($attributes['province'] ?? $current?->province ?? '');
        $boundary = $attributes['boundary_geojson'] ?? $current?->boundary_geojson;

        if (! is_array($boundary)) {
            $normalizedCity = Str::of($city)->squish()->lower()->toString();
            $baseCity = Str::endsWith($normalizedCity, ' city')
                ? Str::beforeLast($normalizedCity, ' city')
                : $normalizedCity;
            $acceptedCityNames = [$baseCity, $baseCity.' city'];
            $duplicate = DeliveryZone::query()
                ->where('status', DeliveryZoneStatus::Active->value)
                ->whereNull('boundary_geojson')
                ->whereIn(DB::raw('LOWER(TRIM(city))'), $acceptedCityNames)
                ->whereRaw('LOWER(TRIM(province)) = ?', [Str::lower($province)])
                ->when($current !== null, fn ($query) => $query->whereKeyNot($current->id))
                ->exists();

            if ($duplicate) {
                throw ValidationException::withMessages([
                    'city' => ['Only one active city-wide fallback zone is allowed for the same city and province.'],
                ]);
            }

            return;
        }

        $overlap = DeliveryZone::query()
            ->where('status', DeliveryZoneStatus::Active->value)
            ->whereNotNull('boundary_geojson')
            ->when($current !== null, fn ($query) => $query->whereKeyNot($current->id))
            ->get(['id', 'boundary_geojson'])
            ->first(fn (DeliveryZone $zone): bool => $this->boundaries->overlaps($boundary, $zone->boundary_geojson));

        if ($overlap !== null) {
            throw ValidationException::withMessages([
                'boundary_geojson' => ["The coverage boundary overlaps active zone #{$overlap->id}."],
            ]);
        }
    }

    /** @return array<string, mixed> */
    private function snapshot(DeliveryZone $zone): array
    {
        return Arr::only($zone->attributesToArray(), [
            'name',
            'city',
            'province',
            'boundary_geojson',
            'base_fee',
            'included_km',
            'maximum_delivery_km',
            'extra_fee_per_km',
            'maximum_delivery_fee',
            'distance_rounding_km',
            'effective_from',
            'status',
        ]);
    }
}
