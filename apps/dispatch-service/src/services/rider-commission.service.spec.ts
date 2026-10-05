import { CommissionType } from '@taladelivery/contracts';
import {
  DispatchSettingsService,
  type DispatchSettingsSnapshot,
} from './dispatch-settings.service';
import { RiderCommissionService } from './rider-commission.service';

const defaultSnapshot: DispatchSettingsSnapshot = {
  riderCommissionType: CommissionType.Percentage,
  riderCommissionValue: '10.00',
  earningsWeekType: 'ROLLING_SEVEN_DAYS',
  weekStartsOn: 1,
  settlementTimezone: 'Asia/Manila',
  settlementDayStartsAt: '00:00',
  distanceMethod: 'STRAIGHT_LINE',
};

const service = new RiderCommissionService({} as unknown as DispatchSettingsService);

describe('RiderCommissionService', () => {
  it('computes a percentage commission from the delivery fee', async () => {
    const result = await service.calculate(15000, defaultSnapshot); // ₱150.00 fee
    expect(result.type).toBe(CommissionType.Percentage);
    expect(result.value).toBe('10.00');
    expect(result.amountMinor).toBe(1500);
    expect(result.amount).toBe('15.00');
  });

  it('rounds percentage commission to the nearest centavo', async () => {
    const result = await service.calculate(1475, {
      ...defaultSnapshot,
      riderCommissionValue: '7.5',
    });
    // 1475 * 7.5 / 100 = 110.625 -> 111 centavos
    expect(result.amountMinor).toBe(111);
    expect(result.amount).toBe('1.11');
  });

  it('pays a fixed commission regardless of the delivery fee', async () => {
    const result = await service.calculate(500000, {
      ...defaultSnapshot,
      riderCommissionType: CommissionType.Fixed,
      riderCommissionValue: '20.00',
    });
    expect(result.amountMinor).toBe(2000);
    expect(result.amount).toBe('20.00');
    expect(result.value).toBe('20.00');
  });

  it('clamps a negative commission to zero', async () => {
    const result = await service.calculate(15000, {
      ...defaultSnapshot,
      riderCommissionValue: '-5.00',
    });
    expect(result.amountMinor).toBe(0);
    expect(result.amount).toBe('0.00');
  });

  it('falls back to the configured snapshot when none is passed', async () => {
    const snapshot = jest.fn(async () => ({
      ...defaultSnapshot,
      riderCommissionType: CommissionType.Fixed,
      riderCommissionValue: '35.00',
    }));
    const fromSettings = new RiderCommissionService(
      { snapshot } as unknown as DispatchSettingsService,
    );
    const result = await fromSettings.calculate(100);
    expect(result.amountMinor).toBe(3500);
    expect(result.amount).toBe('35.00');
  });
});