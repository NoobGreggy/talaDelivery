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
