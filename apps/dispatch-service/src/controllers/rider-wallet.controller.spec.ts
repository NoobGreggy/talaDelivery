jest.mock('@taladelivery/auth', () => ({
  AppKeyGuard: class {},
  JwtAuthGuard: class {},
  CurrentUser: () => () => undefined,
}));
import { JwtPayload } from '@taladelivery/auth';
import { RiderController } from './rider.controller';
import { RiderService } from '../services/rider.service';
import { DispatchResourcesService } from '../services/dispatch-resources.service';
import { RiderEarningsService } from '../services/rider-earnings.service';
import { RiderCoinsService } from '../services/rider-coins.service';
import { runWithRequestContext, requestContext } from '@taladelivery/common';

const user = { sub: 50, role: 'rider' } as JwtPayload;
function harness() {
  const riders = {
    profileByUserId: jest.fn(async (id) =>
      id === 50 ? { id: 5, talaCoinsBalance: '-5.20' } : null,
    ),
  };
  const coins = {
    history: jest.fn(async () => ({
      items: [
        { id: 2, amount: '-10.00', actor_id: 1 },
        { id: 1, amount: '4.80', actor_id: 1 },
      ],
      total: 25,
    })),
  };
  const controller = new RiderController(
    riders as unknown as RiderService,
    {} as DispatchResourcesService,
    {} as RiderEarningsService,
    coins as unknown as RiderCoinsService,
  );
  return { controller, riders, coins };
}
describe('Authenticated rider wallet reads', () => {
  it('resolves balance using the authenticated user, including negative coins', async () => {
    const h = harness();
    expect(await h.controller.wallet(user)).toEqual({
      available_tokens: '-5.20',
      unit: 'Tala Coins',
    });
    expect(h.riders.profileByUserId).toHaveBeenCalledWith(50);
  });
  it('rejects users without their own rider profile', async () => {
    const h = harness();
    await expect(h.controller.wallet({ sub: 99 } as JwtPayload)).rejects.toThrow(
      'Rider profile not found',
    );
    await expect(h.controller.walletTransactions({ sub: 99 } as JwtPayload)).rejects.toThrow(
      'Rider profile not found',
    );
    expect(h.coins.history).not.toHaveBeenCalled();
  });
  it('scopes paginated history to the authenticated rider and exposes direction', async () => {
    const h = harness();
    const result = await runWithRequestContext(
      { ...requestContext(), path: '/api/v1/rider/wallet/transactions' },
      () => h.controller.walletTransactions(user, 2, 20),
    );
    expect(h.coins.history).toHaveBeenCalledWith(5, 2, 20);
    expect(result.meta).toMatchObject({ currentPage: 2, perPage: 20, lastPage: 2, total: 25 });
    expect(result.data[0]).toEqual({
      id: 2,
      amount: '-10.00',
      direction: 'DEBIT',
      status: 'COMPLETED',
    });
    expect(result.data[1].direction).toBe('CREDIT');
  });
  it('bounds oversized pages and defaults invalid query strings', async () => {
    const h = harness();
    await runWithRequestContext({ ...requestContext(), path: '/rider/wallet/transactions' }, () =>
      h.controller.walletTransactions(user, -1, 10000),
    );
    expect(h.coins.history).toHaveBeenCalledWith(5, 1, 100);
    await runWithRequestContext({ ...requestContext(), path: '/rider/wallet/transactions' }, () =>
      h.controller.walletTransactions(user, Number.NaN, Number.NaN),
    );
    expect(h.coins.history).toHaveBeenCalledWith(5, 1, 20);
  });
});
