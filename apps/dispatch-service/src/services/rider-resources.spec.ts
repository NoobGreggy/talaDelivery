import { DispatchResourcesService } from './dispatch-resources.service';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { Rider } from '../entities/rider.entity';
import { RiderMatchingService } from './rider-matching.service';

describe('Rider app delivery resources', () => {
  const delivery = {
    id: 10,
    orderId: 7,
    storeId: 2,
    status: 'UNASSIGNED',
    createdAt: new Date(),
    updatedAt: new Date(),
    pickupAddress: 'Store',
    deliveryAddress: 'Customer',
  } as Delivery;
  const offer = {
    id: 20,
    deliveryId: 10,
    riderId: 5,
    status: 'PENDING',
    createdAt: new Date(),
    offeredAt: new Date(),
    expiresAt: new Date(Date.now() + 60000),
  } as DeliveryOffer;
  function harness() {
    const refs = {
      orderById: jest.fn(async () => ({
        id: 7,
        orderNumber: 'ORD-7',
        customerName: 'Customer',
        customerPhone: '09123456789',
        items: [{ productName: 'Burger', quantity: 2, unitPrice: '99.00' }],
      })),
      storeById: jest.fn(async () => ({ id: 2, name: 'Test Store' })),
    };
    const deliveries = { findOneBy: jest.fn(async () => delivery) };
    return {
      refs,
      deliveries,
      service: new DispatchResourcesService(refs as never, deliveries as never),
    };
  }
  it('pending offers hydrate the delivery, store, and order items', async () => {
    const h = harness();
    const json = await h.service.offerToJson(offer);
    expect(h.deliveries.findOneBy).toHaveBeenCalledWith({ id: 10 });
    expect(json.delivery).toMatchObject({
      id: 10,
      store: { name: 'Test Store' },
      order: { customerPhone: '09123456789', items: [{ productName: 'Burger' }] },
    });
  });
  it('compact admin offer references deliberately skip hydration', async () => {
    const h = harness();
    expect((await h.service.offerToJson(offer, { skipHydration: true })).delivery).toBeNull();
    expect(h.deliveries.findOneBy).not.toHaveBeenCalled();
  });
  it('accepted offers use the supplied authoritative delivery', async () => {
    const h = harness();
    const hydrated = await h.service.deliveryToJson(delivery);
    expect((await h.service.offerToJson(offer, { deliveryJson: hydrated })).delivery).toBe(
      hydrated,
    );
    expect(h.deliveries.findOneBy).not.toHaveBeenCalled();
  });
});

describe('Rider realtime offer audience', () => {
  it('resolves expiry notifications from rider id to identity user id', async () => {
    const events = { publishEvent: jest.fn() };
    const riders = { findOne: jest.fn(async () => ({ id: 5, userId: 50 }) as Rider) };
    const service = new RiderMatchingService(
      {} as never,
      {} as never,
      {} as never,
      events as never,
      {} as never,
      {} as never,
      {} as never,
      riders as never,
    );
    await service.pushOffer({
      id: 20,
      riderId: 5,
      deliveryId: 10,
      status: 'EXPIRED',
      expiresAt: null,
    } as DeliveryOffer);
    expect(events.publishEvent).toHaveBeenCalledWith(
      'realtime-feed',
      'realtime.emit',
      expect.objectContaining({
        rooms: ['user:50'],
        event: 'offer.updated',
        data: expect.objectContaining({ status: 'EXPIRED' }),
      }),
      expect.any(String),
    );
  });
});
