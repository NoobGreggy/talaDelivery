import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  Roles,
  RolesGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import { ForbiddenError, Message, ValidationError } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { DispatchSettingsService } from '../../services/dispatch-settings.service';
import { UpdatePlatformSettingDto } from '../../dto/platform-setting.dto';

/**
 * Admin platform (dispatch) settings (mirrors Laravel
 * AdminPlatformSettingController). Keeps the single-row `dispatch_settings`
 * mirror in sync with delivery pricing / earnings behavior.
 */
@Controller('admin/settings')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminPlatformSettingController {
  constructor(private readonly settings: DispatchSettingsService) {}

  @Get()
  @Message('Platform settings retrieved.')
  async show() {
    const row = await this.settings.current();
    const snapshot = this.settings.toSnapshot(row);
    return {
      rider_commission_type: snapshot.riderCommissionType,
      rider_commission_value: snapshot.riderCommissionValue,
      earnings_week_type: snapshot.earningsWeekType,
      week_starts_on: snapshot.weekStartsOn,
      settlement_timezone: snapshot.settlementTimezone,
      settlement_day_starts_at: snapshot.settlementDayStartsAt,
      distance_method: snapshot.distanceMethod,
      share_ratio: snapshot.shareRatio,
      updated_at: row.updatedAt.toISOString(),
    };
  }

  @Put()
  @Message('Platform settings updated.')
  async update(@CurrentUser() actor: JwtPayload, @Body() dto: UpdatePlatformSettingDto) {
    if (
      dto.rider_commission_type === 'PERCENTAGE' &&
      Number.parseFloat(dto.rider_commission_value) > 100
    ) {
      throw new ValidationError('Percentage commission cannot exceed 100%.', {
        rider_commission_value: ['Percentage commission cannot exceed 100%.'],
      });
    }

    if (dto.share_ratio !== undefined && actor.role !== 'super_admin') {
      throw new ForbiddenError('Only super admins can set the revenue share ratio.');
    }

    const patch: Record<string, unknown> = {
      riderCommissionType: dto.rider_commission_type,
      riderCommissionValue: dto.rider_commission_value,
      earningsWeekType: dto.earnings_week_type,
      weekStartsOn: dto.week_starts_on,
      settlementTimezone: dto.settlement_timezone,
      settlementDayStartsAt: dto.settlement_day_starts_at,
      distanceMethod: dto.distance_method,
    };
    if (dto.share_ratio !== undefined) {
      patch.shareRatio = dto.share_ratio;
    }

    const row = await this.settings.update(patch as never);

    const snapshot = this.settings.toSnapshot(row);
    return {
      rider_commission_type: snapshot.riderCommissionType,
      rider_commission_value: snapshot.riderCommissionValue,
      earnings_week_type: snapshot.earningsWeekType,
      week_starts_on: snapshot.weekStartsOn,
      settlement_timezone: snapshot.settlementTimezone,
      settlement_day_starts_at: snapshot.settlementDayStartsAt,
      distance_method: snapshot.distanceMethod,
      share_ratio: snapshot.shareRatio,
      updated_at: row.updatedAt.toISOString(),
    };
  }
}