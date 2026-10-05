import { Injectable } from '@nestjs/common';
import { DeliveryStatus } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Delivery } from '../entities/delivery.entity';
import { DispatchSettingsService } from './dispatch-settings.service';
import { moneyString } from '../common/format.util';

export interface EarningsPeriod {
  start: string; // ISO 8601 with settlement-timezone offset
  end: string;
  completed_deliveries: number;
  earnings: string; // two-decimal decimal string
}

export interface EarningsSummary {
  timezone: string;
  earnings_week_type: string;
  periods: {
    today: EarningsPeriod;
    week: EarningsPeriod;
    month: EarningsPeriod;
  };
}

/**
 * Mirrors Laravel RiderEarningsService period calculations (settlement
 * timezone day, calendar or rolling seven-day week).
 */
@Injectable()
export class RiderEarningsService {
  constructor(
    private readonly settings: DispatchSettingsService,
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
  ) {}

  async summary(riderId: number, now: Date = new Date()): Promise<EarningsSummary> {
    const config = await this.settings.snapshot();
    const timezone = config.settlementTimezone;

    // Project the instant into wall-clock in the settlement timezone using UTC
    // fields so all arithmetic below is DST-safe.
    const wallClock = toWallClock(now, timezone);
    const [hour, minute] = config.settlementDayStartsAt
      .split(':')
      .map((v) => Number.parseInt(v, 10));
    let dayStart = new Date(wallClock);
    dayStart.setUTCHours(hour, minute, 0, 0);

    if (wallClock.getTime() < dayStart.getTime()) {
      dayStart = new Date(dayStart.getTime() - 86400000);
    }

    const weekStart =
      config.earningsWeekType === 'CALENDAR_WEEK'
        ? calendarWeekStart(dayStart, config.weekStartsOn)
        : new Date(dayStart.getTime() - 6 * 86400000);

    const monthStart = new Date(
      Date.UTC(dayStart.getUTCFullYear(), dayStart.getUTCMonth(), 1),
    );
    monthStart.setUTCHours(hour, minute, 0, 0);

    return {
      timezone,
      earnings_week_type: config.earningsWeekType,
      periods: {
        today: await this.period(riderId, dayStart, wallClock, timezone),
        week: await this.period(riderId, weekStart, wallClock, timezone),
        month: await this.period(riderId, monthStart, wallClock, timezone),
      },
    };
  }

  private async period(
    riderId: number,
    start: Date,
    end: Date,
    timezone: string,
  ): Promise<EarningsPeriod> {
    const rows = await this.deliveries
      .createQueryBuilder('delivery')
      .select('delivery.rider_commission', 'commission')
      .where('delivery.rider_id = :riderId', { riderId })
      .andWhere('delivery.status = :status', { status: DeliveryStatus.Delivered })
      .andWhere('delivery.delivered_at >= :start', { start: start.toISOString() })
      .andWhere('delivery.delivered_at <= :end', { end: end.toISOString() })
      .getRawMany();

    const completed = rows.length;
    const totalMinor = rows.reduce((sum, row) => {
      const value = Number.parseFloat(String(row.commission ?? '0')) || 0;
      return sum + Math.round(value * 100);
    }, 0);

    return {
      start: withZoneOffset(start, timezone),
      end: withZoneOffset(end, timezone),
      completed_deliveries: completed,
      earnings: moneyString(totalMinor / 100),
    };
  }
}

/** Wall-clock representation of an instant in the given zone, as a UTC-field Date. */
function toWallClock(date: Date, timezone: string): Date {
  const parts = timeParts(date, timezone);
  return new Date(
    Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second),
  );
}

/** ISO-8601 wall-clock string with the zone offset (e.g. 2026-09-29T00:00:00+08:00). */
function withZoneOffset(wallClock: Date, timezone: string): string {
  const offsetMinutes = zoneOffsetMinutes(wallClock, timezone);
  const sign = offsetMinutes >= 0 ? '+' : '-';
  const abs = Math.abs(offsetMinutes);
  const hh = String(Math.floor(abs / 60)).padStart(2, '0');
  const mm = String(abs % 60).padStart(2, '0');
  return `${wallClock.toISOString().slice(0, 19)}${sign}${hh}:${mm}`;
}

function zoneOffsetMinutes(wallClock: Date, timezone: string): number {
  // Offset between the zone wall-clock and the same fields interpreted as UTC.
  const zoneParts = timeParts(wallClock, timezone);
  const zoneAsUtc =
    Date.UTC(
      zoneParts.year,
      zoneParts.month - 1,
      zoneParts.day,
      zoneParts.hour,
      zoneParts.minute,
      zoneParts.second,
    ) / 60000;
  return Math.round((zoneAsUtc - wallClock.getTime() / 60000) / 60) * 60;
}

interface TimePart {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

function timeParts(date: Date, timeZone: string): TimePart {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(date);

  const read = (type: string): number => {
    const part = parts.find((p) => p.type === type);
    return Number.parseInt(part?.value ?? '0', 10);
  };

  return {
    year: read('year'),
    month: read('month'),
    day: read('day'),
    hour: read('hour') === 24 ? 0 : read('hour'),
    minute: read('minute'),
    second: read('second'),
  };
}

function calendarWeekStart(dayStart: Date, weekStartsOn: number): Date {
  const dayOfWeek = dayStart.getUTCDay();
  const daysSinceStart = (dayOfWeek - weekStartsOn + 7) % 7;
  return new Date(dayStart.getTime() - daysSinceStart * 86400000);
}