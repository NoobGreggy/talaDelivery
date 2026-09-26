<?php

namespace App\Services;

class ZoneBoundaryService
{
    /** @param array{type: string, coordinates: array<int, array<int, array{0: float|int, 1: float|int}>>} $polygon */
    public function covers(array $polygon, float $latitude, float $longitude): bool
    {
        $ring = $polygon['coordinates'][0] ?? [];
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
                return true;
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

    /**
     * @param  array{type: string, coordinates: array<int, array<int, array{0: float|int, 1: float|int}>>}  $first
     * @param  array{type: string, coordinates: array<int, array<int, array{0: float|int, 1: float|int}>>}  $second
     */
    public function overlaps(array $first, array $second): bool
    {
        $firstRing = $first['coordinates'][0] ?? [];
        $secondRing = $second['coordinates'][0] ?? [];

        foreach (array_slice($firstRing, 0, -1) as [$longitude, $latitude]) {
            if ($this->covers($second, (float) $latitude, (float) $longitude)) {
                return true;
            }
        }

        foreach (array_slice($secondRing, 0, -1) as [$longitude, $latitude]) {
            if ($this->covers($first, (float) $latitude, (float) $longitude)) {
                return true;
            }
        }

        for ($firstIndex = 1; $firstIndex < count($firstRing); $firstIndex++) {
            for ($secondIndex = 1; $secondIndex < count($secondRing); $secondIndex++) {
                if ($this->segmentsIntersect(
                    $firstRing[$firstIndex - 1],
                    $firstRing[$firstIndex],
                    $secondRing[$secondIndex - 1],
                    $secondRing[$secondIndex],
                )) {
                    return true;
                }
            }
        }

        return false;
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
    private function segmentsIntersect(array $firstStart, array $firstEnd, array $secondStart, array $secondEnd): bool
    {
        $orientationOne = $this->orientation($firstStart, $firstEnd, $secondStart);
        $orientationTwo = $this->orientation($firstStart, $firstEnd, $secondEnd);
        $orientationThree = $this->orientation($secondStart, $secondEnd, $firstStart);
        $orientationFour = $this->orientation($secondStart, $secondEnd, $firstEnd);

        return $orientationOne !== $orientationTwo && $orientationThree !== $orientationFour;
    }

    /** @param array{0: float|int, 1: float|int} $start */
    private function orientation(array $start, array $end, array $point): int
    {
        $value = ((float) $end[1] - (float) $start[1]) * ((float) $point[0] - (float) $end[0])
            - ((float) $end[0] - (float) $start[0]) * ((float) $point[1] - (float) $end[1]);

        return $value > 0 ? 1 : ($value < 0 ? -1 : 0);
    }
}
