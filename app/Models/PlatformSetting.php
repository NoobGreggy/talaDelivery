<?php

namespace App\Models;

use Database\Factories\PlatformSettingFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['key', 'rider_commission_type', 'rider_commission_value', 'earnings_week_type', 'week_starts_on', 'settlement_timezone', 'settlement_day_starts_at', 'distance_method'])]
class PlatformSetting extends Model
{
    /** @use HasFactory<PlatformSettingFactory> */
    use HasFactory;

    /**
     * Keep database defaults available on the model returned by firstOrCreate().
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'rider_commission_type' => 'PERCENTAGE',
        'rider_commission_value' => 0,
        'earnings_week_type' => 'ROLLING_SEVEN_DAYS',
        'week_starts_on' => 1,
        'settlement_timezone' => 'Asia/Manila',
        'settlement_day_starts_at' => '00:00:00',
        'distance_method' => 'STRAIGHT_LINE',
    ];

    public static function current(): self
    {
        return self::query()->firstOrCreate(['key' => 'platform']);
    }

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'rider_commission_value' => 'decimal:2',
            'week_starts_on' => 'integer',
        ];
    }
}
