import { DeliveryStatus } from '@taladelivery/contracts';
import { Repository } from 'typeorm';
import { Delivery } from '../entities/delivery.entity';
import {
  DispatchSettingsService,
  type DispatchSettingsSnapshot,
} from './dispatch-settings.service';
import {
  type EarningsSummary,
  RiderEarningsService,
} from './rider-earnings.service';

const rows = [{ commission: '60.00' }, { commission: '12.50' }];

const baseSnapshot: DispatchSettingsSnapshot = {
  riderCommissionType: 'PERCENTAGE',
  riderCommissionValue: '10.00',
  earningsWeekType: 'CALENDAR_WEEK',
  weekStartsOn: 1, // Monday
  settlementTimezone: 'Asia/Manila',
  settlementDayStartsAt: '00:00',
  distanceMethod: 'STRAIGHT_LINE',
};

/**
 * Builds a fake deliveries repository that records the bound query parameters
 * of every period query (three per summary call: today, week, month).
 */
function deliveriesRepo(): {
  repo: Repository<Delivery>;
  periods: Array<Record<string, unknown>>;
} {
  const periods: Array<Record<string, unknown>> = [];
  const repo = {
    createQueryBuilder: jest.fn(() => {
      const bound: Record<string, unknown> = {};
      const chain: {
        select: jest.Mock;
        where: jest.Mock;
        andWhere: jest.Mock;
        getRawMany: jest.Mock;
      } = {
        select: jest.fn(() => chain),
        where: jest.fn((_q: string, params: Record<string, unknown>) => {
          Object.assign(bound, params);
          return chain;
        }),
        andWhere: jest.fn((_q: string, params: Record<string, unknown>) => {
          Object.assign(bound, params);
          return chain;
        }),
        getRawMany: jest.fn(async () => rows),
      };
      periods.push(bound);
      return chain;
    }),
  };
  return { repo: repo as unknown as Repository<Delivery>, periods };
}

async function summaryFor(
  snapshot: DispatchSettingsSnapshot,
  now: Date,
): Promise<{ summary: EarningsSummary; periods: Array<Record<string, unknown>> }> {
  const settings = { snapshot: jest.fn(async () => snapshot) } as unknown as DispatchSettingsService;
  const { repo, periods } = deliveriesRepo();
  const service = new RiderEarningsService(settings, repo);
  const summary = await service.summary(5, now);
  return { summary, periods };
}

// Tuesday 2026-09-29, 02:00 UTC == 10:00 in Asia/Manila (+08:00)
const NOW = new Date('2026-09-29T02:00:00.000Z');

describe('RiderEarningsService.summary', () => {
  it('sums delivered commissions and counts deliveries per period', async () => {
    const { summary } = await summaryFor(baseSnapshot, NOW);

    expect(summary.timezone).toBe('Asia/Manila');
    expect(summary.earnings_week_type).toBe('CALENDAR_WEEK');
    for (const period of Object.values(summary.periods)) {
      expect(period.completed_deliveries).toBe(2);
      expect(period.earnings).toBe('72.50');
    }
  });

  it('starts the calendar week on the configured weekday', async () => {
    const { periods } = await summaryFor(baseSnapshot, NOW);

    // today: settlement day (00:00 Manila) -> 2026-09-29T00:00:00Z
    expect(periods[0].start).toBe('2026-09-29T00:00:00.000Z');
    expect(periods[0].end).toBe('2026-09-29T10:00:00.000Z');
    // calendar week: Monday 2026-09-28
    expect(periods[1].start).toBe('2026-09-28T00:00:00.000Z');
    // calendar month: 1st of September
    expect(periods[2].start).toBe('2026-09-01T00:00:00.000Z');
  });

  it('uses a rolling seven-day window when configured', async () => {
    const { periods } = await summaryFor(
      { ...baseSnapshot, earningsWeekType: 'ROLLING_SEVEN_DAYS' },
      NOW,
    );

    // rolling week: dayStart minus 6 days
    expect(periods[1].start).toBe('2026-09-23T00:00:00.000Z');
  });

  it('formats period bounds with the settlement timezone offset', async () => {
    const { summary } = await summaryFor(baseSnapshot, NOW);

    expect(summary.periods.today.start).toBe('2026-09-29T00:00:00+08:00');
    expect(summary.periods.today.end).toBe('2026-09-29T10:00:00+08:00');
  });

  it('honours a custom settlement day start time', async () => {
    // Day starts at 06:00: at 10:00 Manila on the 29th the settlement day
    // still begins on the 29th, but earlier in the morning.
    const { periods } = await summaryFor(
      { ...baseSnapshot, settlementDayStartsAt: '06:00' },
      NOW,
    );

    expect(periods[0].start).toBe('2026-09-29T06:00:00.000Z');
  });

  it('only ever counts deliveries with status DELIVERED', async () => {
    const settings = { snapshot: jest.fn(async () => baseSnapshot) } as unknown as DispatchSettingsService;
    const whereCalls: Array<{ q: string; p: Record<string, unknown> }> = [];
    const repo = {
      createQueryBuilder: jest.fn(() => {
        const chain: {
          select: jest.Mock;
          where: jest.Mock;
          andWhere: jest.Mock;
          getRawMany: jest.Mock;
        } = {
          select: jest.fn(() => chain),
          where: jest.fn((q: string, p: Record<string, unknown>) => {
            whereCalls.push({ q, p });
            return chain;
          }),
          andWhere: jest.fn((q: string, p: Record<string, unknown>) => {
            whereCalls.push({ q, p });
            return chain;
          }),
          getRawMany: jest.fn(async () => []),
        };
        return chain;
      }),
    } as unknown as Repository<Delivery>;

    const service = new RiderEarningsService(settings, repo);
    await service.summary(5, NOW);

    const statusFilters = whereCalls.filter(
      (call) => call.q.includes('delivery.status = :status'),
    );
    expect(statusFilters.length).toBe(3);
    for (const call of statusFilters) {
      expect(call.p.status).toBe(DeliveryStatus.Delivered);
    }
  });
});