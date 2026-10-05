import { validate } from 'class-validator';
import { UpdateDeliveryZoneDto } from './delivery-zone.dto';
import { TopUpRiderCoinsDto } from './rider-coins.dto';

describe('Tala Coins API validation', () => {
  it.each(['0', '0.01', '12.50', '100', '100.00'])('accepts zone percentage %s', async (value) => {
    const dto = Object.assign(new UpdateDeliveryZoneDto(), { tala_coins_percent: value });
    expect(await validate(dto)).toHaveLength(0);
  });
  it.each(['-1', '101', '100.01', '1.001', 'NaN', '', null, 10])('rejects invalid percentage %s', async (value) => {
    const dto = Object.assign(new UpdateDeliveryZoneDto(), { tala_coins_percent: value });
    expect((await validate(dto)).some((error) => error.property === 'tala_coins_percent')).toBe(true);
  });
  it('allows updating other fields without changing the deduction rate', async () => {
    expect(await validate(Object.assign(new UpdateDeliveryZoneDto(), { name: 'New name' }))).toHaveLength(0);
  });
  it.each(['-1', '1.001', '100000000.00', 'NaN'])('rejects invalid top-up amount %s', async (amount) => {
    const dto = Object.assign(new TopUpRiderCoinsDto(), { amount, request_id: 'c5cba3ad-79be-4b73-8786-df49b3305980' });
    expect((await validate(dto)).some((error) => error.property === 'amount')).toBe(true);
  });
  it('requires an idempotency key for top-ups', async () => {
    const dto = Object.assign(new TopUpRiderCoinsDto(), { amount: '10.00' });
    expect((await validate(dto)).some((error) => error.property === 'request_id')).toBe(true);
  });
});
