<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Translation\PotentiallyTranslatedString;

class ValidGeoJsonPolygon implements ValidationRule
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

        if (! is_array($value) || ($value['type'] ?? null) !== 'Polygon') {
            $fail("The {$attribute} must be a GeoJSON Polygon.");

            return;
        }

        $coordinates = $value['coordinates'] ?? null;
        if (! is_array($coordinates) || count($coordinates) !== 1 || ! is_array($coordinates[0] ?? null)) {
            $fail("The {$attribute} must contain exactly one polygon ring.");

            return;
        }

        $ring = $coordinates[0];
        if (count($ring) < 4) {
            $fail("The {$attribute} must contain at least three vertices and a closing point.");

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

        if ($ring[0] !== $ring[array_key_last($ring)]) {
            $fail("The {$attribute} polygon must be closed.");

            return;
        }

        $uniqueVertices = array_unique(array_map(
            fn (array $point): string => ((float) $point[0]).','.((float) $point[1]),
            array_slice($ring, 0, -1),
        ));

        if (count($uniqueVertices) < 3) {
            $fail("The {$attribute} must contain at least three distinct vertices.");
        }
    }
}
