<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Translation\PotentiallyTranslatedString;

class ValidGeoJsonBoundary implements ValidationRule
{
    /**
     * Run the validation rule.
     *
     * @param  Closure(string, ?string=): PotentiallyTranslatedString  $fail
     */
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if ($value === null) {
            return;
        }

        $type = is_array($value) ? ($value['type'] ?? null) : null;
        $coordinates = is_array($value) ? ($value['coordinates'] ?? null) : null;
        if (! in_array($type, ['Polygon', 'MultiPolygon'], true) || ! is_array($coordinates)) {
            $fail("The {$attribute} must be a GeoJSON Polygon or MultiPolygon.");

            return;
        }

        $polygons = $type === 'Polygon' ? [$coordinates] : $coordinates;
        if ($polygons === [] || count($polygons) > 100) {
            $fail("The {$attribute} contains an invalid number of polygons.");

            return;
        }

        $pointCount = 0;
        foreach ($polygons as $polygon) {
            if (! is_array($polygon) || $polygon === []) {
                $fail("Each {$attribute} polygon must contain an outer ring.");

                return;
            }

            foreach ($polygon as $ring) {
                if (! is_array($ring) || count($ring) < 4) {
                    $fail("Each {$attribute} ring must contain at least three vertices and a closing point.");

                    return;
                }

                $pointCount += count($ring);
                if ($pointCount > 20000) {
                    $fail("The {$attribute} boundary is too detailed. Please choose a simplified boundary.");

                    return;
                }

                foreach ($ring as $point) {
                    if (! is_array($point) || count($point) !== 2 || ! is_numeric($point[0]) || ! is_numeric($point[1])) {
                        $fail("Each {$attribute} coordinate must contain longitude and latitude.");

                        return;
                    }

                    if ((float) $point[0] < -180 || (float) $point[0] > 180 || (float) $point[1] < -90 || (float) $point[1] > 90) {
                        $fail("The {$attribute} contains an invalid longitude or latitude.");

                        return;
                    }
                }

                $first = $ring[0];
                $last = $ring[array_key_last($ring)];
                if ((float) $first[0] !== (float) $last[0] || (float) $first[1] !== (float) $last[1]) {
                    $fail("Each {$attribute} polygon ring must be closed.");

                    return;
                }

                $uniqueVertices = array_unique(array_map(
                    fn (array $point): string => ((float) $point[0]).','.((float) $point[1]),
                    array_slice($ring, 0, -1),
                ));

                if (count($uniqueVertices) < 3) {
                    $fail("Each {$attribute} ring must contain at least three distinct vertices.");

                    return;
                }
            }
        }
    }
}
