import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DispatchSetting } from '../entities/dispatch-setting.entity';

export const DISPATCH_SETTINGS_KEY = 'platform';

export interface DispatchSettingsSnapshot {
  riderCommissionType: string;
  riderCommissionValue: string;
  earningsWeekType: string;
  weekStartsOn: number;
  settlementTimezone: string;
  settlementDayStartsAt: string;
  distanceMethod: string;
}

@Injectable()
export class DispatchSettingsService {
  constructor(
    @InjectRepository(DispatchSetting)
    private readonly settings: Repository<DispatchSetting>,
  ) {}

  /** Lazy-creates the single settings row on first access (mirrors PlatformSetting::current). */
  async current(): Promise<DispatchSetting> {
    let row = await this.settings.findOne({ where: { key: DISPATCH_SETTINGS_KEY } });
    if (!row) {
      row = await this.settings.save(this.settings.create({ key: DISPATCH_SETTINGS_KEY }));
    }
    return row;
  }

  async snapshot(): Promise<DispatchSettingsSnapshot> {
    const row = await this.current();
    return this.toSnapshot(row);
  }

  toSnapshot(row: DispatchSetting): DispatchSettingsSnapshot {
    return {
      riderCommissionType: row.riderCommissionType,
      riderCommissionValue: row.riderCommissionValue ?? '0.00',
      earningsWeekType: row.earningsWeekType,
      weekStartsOn: row.weekStartsOn,
      settlementTimezone: row.settlementTimezone,
      settlementDayStartsAt: row.settlementDayStartsAt,
      distanceMethod: row.distanceMethod,
    };
  }

  async update(patch: Partial<DispatchSetting>): Promise<DispatchSetting> {
    const row = await this.current();
    Object.assign(row, patch);
    return this.settings.save(row);
  }
}