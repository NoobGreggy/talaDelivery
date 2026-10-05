import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import {
  CommissionType,
  DistanceMethod,
  EarningsWeekType,
} from '@taladelivery/contracts';
import { NUMERIC_STRING } from './delivery-zone.dto';

/**
 * Admin PUT admin/settings (mirrors AdminPlatformSettingController::update).
 * Money values are decimal strings; a custom "percentage <= 100" rule runs in
 * the controller to keep the Laravel-exact error shape.
 */
export class UpdatePlatformSettingDto {
  @IsIn([CommissionType.Fixed, CommissionType.Percentage])
  rider_commission_type: string;

  @IsString()
  @Matches(NUMERIC_STRING)
  rider_commission_value: string;

  @IsIn([EarningsWeekType.RollingSevenDays, EarningsWeekType.CalendarWeek])
  earnings_week_type: string;

  @IsInt()
  @Min(0)
  @Max(6)
  week_starts_on: number;

  @IsString()
  settlement_timezone: string;

  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  settlement_day_starts_at: string;

  @IsIn([DistanceMethod.StraightLine, DistanceMethod.RoadRoute])
  distance_method: string;
}

/** Partial variant used by tests / dev seeding. */
export class PatchPlatformSettingDto {
  @IsOptional()
  @IsIn([CommissionType.Fixed, CommissionType.Percentage])
  rider_commission_type?: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  rider_commission_value?: string;

  @IsOptional()
  @IsIn([EarningsWeekType.RollingSevenDays, EarningsWeekType.CalendarWeek])
  earnings_week_type?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(6)
  week_starts_on?: number;

  @IsOptional()
  @IsString()
  settlement_timezone?: string;

  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  settlement_day_starts_at?: string;

  @IsOptional()
  @IsIn([DistanceMethod.StraightLine, DistanceMethod.RoadRoute])
  distance_method?: string;
}