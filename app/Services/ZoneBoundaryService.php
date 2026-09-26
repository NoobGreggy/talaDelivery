<?php

namespace App\Services;

class ZoneBoundaryService
{
    /** @param array<string, mixed> $boundary */
    public function covers(array $boundary, float $latitude, float $longitude): bool
    {
        foreach ($this->polygons($boundary) as $polygon) {
            $outerRing = $polygon[0] ?? [];
            if (! $this->ringContains($outerRing, $latitude, $longitude, true)) {
                continue;
            }

            $insideHole = collect(array_slice($polygon, 1))
                ->contains(fn (array $hole): bool => $this->ringContains($hole, $latitude, $longitude, true));

            if (! $insideHole) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param  array<string, mixed>  $first
     * @param  array<string, mixed>  $second
     */
    public function overlaps(array $first, array $second): bool
    {
        if ($first === $second) {
            return true;
        }

        foreach ($this->polygons($first) as $firstPolygon) {
            foreach ($this->polygons($second) as $secondPolygon) {
                if ($this->polygonsOverlap($firstPolygon, $secondPolygon)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * @param  array<int, array<int, array{0: float|int, 1: float|int}>>  $first
     * @param  array<int, array<int, array{0: float|int, 1: float|int}>>  $second
     */
    private function polygonsOverlap(array $first, array $second): bool
    {
        $firstOuterRing = $first[0] ?? [];
        $secondOuterRing = $second[0] ?? [];

        foreach (array_slice($firstOuterRing, 0, -1) as [$longitude, $latitude]) {
            if ($this->ringContains($secondOuterRing, (float) $latitude, (float) $longitude, false)) {
                return true;
            }
        }

        foreach (array_slice($secondOuterRing, 0, -1) as [$longitude, $latitude]) {
            if ($this->ringContains($firstOuterRing, (float) $latitude, (float) $longitude, false)) {
                return true;
            }
        }

        for ($firstIndex = 1; $firstIndex < count($firstOuterRing); $firstIndex++) {
            for ($secondIndex = 1; $secondIndex < count($secondOuterRing); $secondIndex++) {
                if ($this->segmentsProperlyIntersect(
                    $firstOuterRing[$firstIndex - 1],
                    $firstOuterRing[$firstIndex],
                    $secondOuterRing[$secondIndex - 1],
                    $secondOuterRing[$secondIndex],
                )) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * @param  array<int, array{0: float|int, 1: float|int}>  $ring
     */
    private function ringContains(array $ring, float $latitude, float $longitude, bool $includeBoundary): bool
    {
        if (count($ring) < 4) {
            return false;
        }

        $inside = false;
        $lastIndex = count($ring) - 1;

        for ($index = 0, $previous = $lastIndex; $index <= $lastIndex; $previous = $index++) {
            [$currentLongitude, $currentLatitude] = $ring[$index];
            [$previousLongitude, $previousLatitude] = $ring[$previous];

            if ($this->pointIsOnSegment(
                $longitude,
                $latitude,
                (float) $previousLongitude,
                (float) $previousLatitude,
                (float) $currentLongitude,
                (float) $currentLatitude,
            )) {
                return $includeBoundary;
            }

            $crossesLatitude = ((float) $currentLatitude > $latitude) !== ((float) $previousLatitude > $latitude);
            if (! $crossesLatitude) {
                continue;
            }

            $intersectionLongitude = ((float) $previousLongitude - (float) $currentLongitude)
                * ($latitude - (float) $currentLatitude)
                / ((float) $previousLatitude - (float) $currentLatitude)
                + (float) $currentLongitude;

            if ($longitude < $intersectionLongitude) {
                $inside = ! $inside;
            }
        }

        return $inside;
    }

    private function pointIsOnSegment(
        float $pointX,
        float $pointY,
        float $startX,
        float $startY,
        float $endX,
        float $endY,
    ): bool {
        $crossProduct = ($pointY - $startY) * ($endX - $startX) - ($pointX - $startX) * ($endY - $startY);
        if (abs($crossProduct) > 0.0000001) {
            return false;
        }

        return $pointX >= min($startX, $endX) - 0.0000001
            && $pointX <= max($startX, $endX) + 0.0000001
            && $pointY >= min($startY, $endY) - 0.0000001
            && $pointY <= max($startY, $endY) + 0.0000001;
    }

    /** @param array{0: float|int, 1: float|int} $firstStart */
    private function segmentsProperlyIntersect(array $firstStart, array $firstEnd, array $secondStart, array $secondEnd): bool
    {
        $orientationOne = $this->orientation($firstStart, $firstEnd, $secondStart);
        $orientationTwo = $this->orientation($firstStart, $firstEnd, $secondEnd);
        $orientationThree = $this->orientation($secondStart, $secondEnd, $firstStart);
        $orientationFour = $this->orientation($secondStart, $secondEnd, $firstEnd);

        return $orientationOne !== 0
            && $orientationTwo !== 0
            && $orientationThree !== 0
            && $orientationFour !== 0
            && $orientationOne !== $orientationTwo
            && $orientationThree !== $orientationFour;
    }

    /** @param array{0: float|int, 1: float|int} $start */
    private function orientation(array $start, array $end, array $point): int
    {
        $value = ((float) $end[1] - (float) $start[1]) * ((float) $point[0] - (float) $end[0])
            - ((float) $end[0] - (float) $start[0]) * ((float) $point[1] - (float) $end[1]);

        return $value > 0 ? 1 : ($value < 0 ? -1 : 0);
    }

    /**
     * @param  array<string, mixed>  $boundary
     * @return array<int, array<int, array<int, array{0: float|int, 1: float|int}>>>
     */
    private function polygons(array $boundary): array
    {
        $coordinates = $boundary['coordinates'] ?? [];

        return ($boundary['type'] ?? null) === 'MultiPolygon' ? $coordinates : [$coordinates];
    }
}
