import { DataSource, EntityManager, Repository } from 'typeorm';
import { EventPublisher } from '@taladelivery/events';
import { Delivery } from '../entities/delivery.entity';
import { Rider } from '../entities/rider.entity';
import { RiderCoinTransaction } from '../entities/rider-coin-transaction.entity';
import { RemoteReferencesService } from './remote-references.service';
import { RiderCoinsService } from './rider-coins.service';

function harness(balance = '5.00') {
  const rider = { id: 5, userId: 50, talaCoinsBalance: balance } as Rider;
  const ledger: RiderCoinTransaction[] = [];
  const chain = { setLock: jest.fn(), where: jest.fn(), getOne: jest.fn(async () => rider) };
  chain.setLock.mockReturnValue(chain); chain.where.mockReturnValue(chain);
  const riders = {
    createQueryBuilder: jest.fn(() => chain),
    update: jest.fn(async (_criteria, changes) => { Object.assign(rider, changes); }),
    findOneByOrFail: jest.fn(async () => rider),
  };
  const transactions = {
    create: jest.fn((data) => data),
    save: jest.fn(async (data) => {
      if (data.deliveryId && ledger.some((row) => row.deliveryId === data.deliveryId)) throw new Error('duplicate delivery');
      const row = { ...data, id: ledger.length + 1, createdAt: new Date() }; ledger.push(row); return row;
    }),
    findOneBy: jest.fn(async ({ requestId }) => ledger.find((row) => row.requestId === requestId) ?? null),
    find: jest.fn(async () => ledger.filter((row) => row.adminAlertPending)),
    update: jest.fn(async ({ id }, changes) => { Object.assign(ledger.find((row) => row.id === id)!, changes); }),
  };
  const manager = { getRepository: jest.fn((entity) => entity === Rider ? riders : transactions) } as unknown as EntityManager;
  const dataSource = {
    transaction: jest.fn(async (callback) => {
      const savedBalance = rider.talaCoinsBalance;
      const savedLength = ledger.length;
      try { return await callback(manager); }
      catch (error) { rider.talaCoinsBalance = savedBalance; ledger.splice(savedLength); throw error; }
    }),
    getRepository: jest.fn(() => riders),
  };
  const refs = {
    activePlatformAdmins: jest.fn(async () => [{ id: 1 }, { id: 2 }]),
    userById: jest.fn(async () => ({ id: 50, name: 'Test Rider', phone: '09123456789' })),
  };
  const events = { addJob: jest.fn(async () => true) };
  const service = new RiderCoinsService(dataSource as unknown as DataSource,
    transactions as unknown as Repository<RiderCoinTransaction>,
    refs as unknown as RemoteReferencesService, events as unknown as EventPublisher);
  const delivery = { id: 10, riderId: 5, deliveryZoneId: 3, deliveryFee: '100.00', talaCoinsPercent: '10.00' } as Delivery;
  return { service, manager, rider, ledger, transactions, events, refs, delivery, dataSource };
}

describe('Rider Tala Coins', () => {
  it('deducts the saved zone percentage of the delivery fee and allows a negative balance', async () => {
    const h = harness();
    await h.service.deduct(h.manager, h.delivery);
    expect(h.rider.talaCoinsBalance).toBe('-5.00');
    expect(h.ledger[0]).toMatchObject({ amount: '-10.00', balanceAfter: '-5.00', deductionPercent: '10.00', deliveryZoneId: 3, adminAlertPending: true });
  });

  it('rounds fractional coins to two decimals', async () => {
    const h = harness('100.00');
    await h.service.deduct(h.manager, { ...h.delivery, deliveryFee: '49.99', talaCoinsPercent: '12.50' });
    expect(h.ledger[0].amount).toBe('-6.25');
    expect(h.rider.talaCoinsBalance).toBe('93.75');
  });

  it('does not deduct when the zone percentage or fee is zero', async () => {
    const h = harness();
    await h.service.deduct(h.manager, { ...h.delivery, talaCoinsPercent: '0.00' });
    await h.service.deduct(h.manager, { ...h.delivery, deliveryFee: '0.00' });
    expect(h.ledger).toHaveLength(0);
    expect(h.rider.talaCoinsBalance).toBe('5.00');
  });

  it('keeps deducting below zero without repeating the crossing alert', async () => {
    const h = harness('-5.00');
    await h.service.deduct(h.manager, h.delivery);
    expect(h.rider.talaCoinsBalance).toBe('-15.00');
    expect(h.ledger[0].adminAlertPending).toBe(false);
  });

  it('does not alert for a balance of exactly zero', async () => {
    const h = harness('10.00');
    await h.service.deduct(h.manager, h.delivery);
    expect(h.rider.talaCoinsBalance).toBe('0.00');
    expect(h.ledger[0].adminAlertPending).toBe(false);
  });

  it('applies a top-up once even when the request is retried', async () => {
    const h = harness('-5.00');
    const dto = { amount: '20.00', request_id: 'c5cba3ad-79be-4b73-8786-df49b3305980', note: 'Cash payment' };
    await h.service.topUp(5, dto, 1);
    await h.service.topUp(5, dto, 1);
    expect(h.rider.talaCoinsBalance).toBe('15.00');
    expect(h.ledger).toHaveLength(1);
    expect(h.ledger[0]).toMatchObject({ type: 'TOP_UP', actorId: 1, note: 'Cash payment' });
  });

  it('rejects reusing a top-up request with a different amount', async () => {
    const h = harness();
    const dto = { amount: '20.00', request_id: 'c5cba3ad-79be-4b73-8786-df49b3305980' };
    await h.service.topUp(5, dto, 1);
    await expect(h.service.topUp(5, { ...dto, amount: '30.00' }, 1)).rejects.toThrow('already been used');
    expect(h.rider.talaCoinsBalance).toBe('25.00');
  });

  it('rejects zero top-ups', async () => {
    const h = harness();
    await expect(h.service.topUp(5, { amount: '0', request_id: 'unused' }, 1)).rejects.toThrow('greater than zero');
    expect(h.ledger).toHaveLength(0);
  });

  it('alerts admins with rider contact details and clears the pending alert', async () => {
    const h = harness();
    await h.service.deduct(h.manager, h.delivery);
    await h.service.flushAlerts();
    expect(h.events.addJob).toHaveBeenCalledTimes(2);
    expect(h.events.addJob).toHaveBeenNthCalledWith(1, expect.any(String), 'event', expect.objectContaining({ data: expect.objectContaining({
      userId: 1, type: 'admin.rider_coins_negative', sourceKey: 'rider-coins:1:1',
      data: expect.objectContaining({ riderId: 5, phone: '09123456789', balance: '-5.00' }),
    }) }), expect.any(Object));
    expect(h.ledger[0].adminAlertPending).toBe(false);
  });

  it('retains the alert for retry when the broker drops the job', async () => {
    const h = harness();
    await h.service.deduct(h.manager, h.delivery);
    h.events.addJob.mockResolvedValue(false);
    await h.service.flushAlerts();
    expect(h.ledger[0].adminAlertPending).toBe(true);
    h.events.addJob.mockResolvedValue(true);
    await h.service.flushAlerts();
    expect(h.ledger[0].adminAlertPending).toBe(false);
  });

  it('keeps an alert pending if no active admin is available', async () => {
    const h = harness();
    await h.service.deduct(h.manager, h.delivery);
    h.refs.activePlatformAdmins.mockResolvedValue([]);
    await h.service.flushAlerts();
    expect(h.ledger[0].adminAlertPending).toBe(true);
    expect(h.events.addJob).not.toHaveBeenCalled();
  });

  it('allows a new crossing alert after the rider tops up', async () => {
    const h = harness('-5.00');
    await h.service.topUp(5, { amount: '10.00', request_id: 'c5cba3ad-79be-4b73-8786-df49b3305980' }, 1);
    await h.service.deduct(h.manager, h.delivery);
    expect(h.ledger[1].adminAlertPending).toBe(true);
  });
});
