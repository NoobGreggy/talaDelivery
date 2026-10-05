import { Injectable } from '@nestjs/common';
import { toMinor, fromMinor } from '@taladelivery/common';
import { CommissionType } from '@taladelivery/contracts';
import {
  DispatchSettingsService,
  type DispatchSettingsSnapshot,
} from './dispatch-settings.service';

export interface CommissionResult {
  /** commission in centavos (integer money) */
  amountMinor: number;
  /** commission as two-decimal string */
  amount: string;
  type: string;
  /** configured value as two-decimal string */
  value: string;
}

/**
 * Mirrors Laravel RiderCommissionService. deliveryFeeMinor is the integer
 * centavo amount (from the pricing breakdown).
 */
@Injectable()
export class RiderCommissionService {
  constructor(private readonly settings: DispatchSettingsService) {}

  async calculate(
    deliveryFeeMinor: number,
    settings?: DispatchSettingsSnapshot,
  ): Promise<CommissionResult> {
    const config = settings ?? (await this.settings.snapshot());
    const type = config.riderCommissionType;
    const value = Number.parseFloat(config.riderCommissionValue ?? '0') || 0;

    const amountMinor =
      type === CommissionType.Fixed
        ? toMinor(value)
        : Math.round((deliveryFeeMinor * value) / 100);

    return {
      amountMinor: Math.max(0, amountMinor),
      amount: fromMinor(Math.max(0, amountMinor)),
      type,
      value: fromMinor(toMinor(value)),
    };
  }
}