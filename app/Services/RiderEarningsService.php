<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Models\PlatformSetting;
use App\Models\User;
use Carbon\CarbonImmutable;

class RiderEarningsService
{
    /**
     * @return array<string, mixed>
     */
    public function summary(User $rider, ?CarbonImmutable $now = null): array
    {
        $settings = PlatformSetting::current();
        $timezone = $settings->settlement_timezone;
        $now = ($now ?? CarbonImmutable::now($timezone))->setTimezone($timezone);
        [$hour, $minute] = array_map('intval', explode(':', $settings->settlement_day_starts_at));
        $dayStart = $now->setTime($hour, $minute);

        if ($now->lessThan($dayStart)) {
            $dayStart = $dayStart->subDay();
        }

        $weekStart = $settings->earnings_week_type === 'CALENDAR_WEEK'
            ? $this->calendarWeekStart($dayStart, (int) $settings->week_starts_on)
            : $dayStart->subDays(6);
        $monthStart = $dayStart->startOfMonth()->setTime($hour, $minute);

        return [
            'timezone' => $timezone,
            'earnings_week_type' => $settings->earnings_week_type,
            'periods' => [
                'today' => $this->period($rider, $dayStart, $now),
                'week' => $this->period($rider, $weekStart, $now),
                'month' => $this->period($rider, $monthStart, $now),
            ],
        ];
    }

    private function calendarWeekStart(CarbonImmutable $dayStart, int $weekStartsOn): CarbonImmutable
    {
        $daysSinceStart = ($dayStart->dayOfWeek - $weekStartsOn + 7) % 7;

        return $dayStart->subDays($daysSinceStart);
    }

    /**
     * @return array{start: string, end: string, completed_deliveries: int, earnings: float}
     */
    private function period(User $rider, CarbonImmutable $start, CarbonImmutable $end): array
    {
        $query = $rider->deliveriesAsRider()
            ->where('status', DeliveryStatus::Delivered)
            ->whereBetween('delivered_at', [$start->utc(), $end->utc()]);

        return [
            'start' => $start->toIso8601String(),
            'end' => $end->toIso8601String(),
            'completed_deliveries' => (clone $query)->count(),
            'earnings' => round((float) $query->sum('rider_commission'), 2),
        ];
    }
}
