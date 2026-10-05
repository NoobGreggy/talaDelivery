import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import {
  AppKeyGuard,
  JwtAuthGuard,
  Roles,
  RolesGuard,
} from '@taladelivery/auth';
import { Message, ValidationError } from '@taladelivery/common';
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
    return {
      ...this.settings.toSnapshot(row),
      updated_at: row.updatedAt.toISOString(),
    };
  }

  @Put()
  @Message('Platform settings updated.')
  async update(@Body() dto: UpdatePlatformSettingDto) {
    if (
      dto.rider_commission_type === 'PERCENTAGE' &&
      Number.parseFloat(dto.rider_commission_value) > 100
    ) {
      throw new ValidationError('Percentage commission cannot exceed 100%.', {
        rider_commission_value: ['Percentage commission cannot exceed 100%.'],
      });
    }

    const row = await this.settings.update({
      riderCommissionType: dto.rider_commission_type,
      riderCommissionValue: dto.rider_commission_value,
      earningsWeekType: dto.earnings_week_type,
      weekStartsOn: dto.week_starts_on,
      settlementTimezone: dto.settlement_timezone,
      settlementDayStartsAt: dto.settlement_day_starts_at,
      distanceMethod: dto.distance_method,
    });

    return {
      ...this.settings.toSnapshot(row),
      updated_at: row.updatedAt.toISOString(),
    };
  }
}