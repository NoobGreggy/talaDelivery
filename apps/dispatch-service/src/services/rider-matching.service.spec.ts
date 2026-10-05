import { ConfigService } from '@nestjs/config';
import {
  DeliveryOfferStatus,
  DeliveryStatus,
  RiderStatus,
} from '@taladelivery/contracts';
import {
  EventType,
  EventPublisher,
  QueueName,
} from '@taladelivery/events';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { Rider } from '../entities/rider.entity';
import { OfferExpiryScheduler } from './offer-expiry-scheduler.service';
import { PricingService } from './pricing.service';
import { RiderMatchingService } from './rider-matching.service';

function builderChain(getValue: () => unknown): {
  setLock: jest.Mock;
  where: jest.Mock;
  andWhere: jest.Mock;
  orderBy: jest.Mock;
  getOne: jest.Mock;
  getMany: jest.Mock;
  getExists: jest.Mock;
} {
  const chain: {
    setLock: jest.Mock;
    where: jest.Mock;
    andWhere: jest.Mock;
    orderBy: jest.Mock;
    getOne: jest.Mock;
    getMany: jest.Mock;
    getExists: jest.Mock;
  } = {
    setLock: jest.fn(() => chain),
    where: jest.fn(() => chain),
    andWhere: jest.fn(() => chain),
    orderBy: jest.fn(() => chain),
    getOne: jest.fn(async () => getValue()),
    getMany: jest.fn(async () => getValue()),
    getExists: jest.fn(async () => getValue()),
  };
  return chain;
}

interface Harness {
  service: RiderMatchingService;
  state: { offer: DeliveryOffer | null; delivery: Delivery | null; candidates: Rider[] };
  pricing: { distanceKm: jest.Mock };
  events: { publishEvent: jest.Mock };
  offerExpiry: { schedule: jest.Mock };
  deliveries: { findOne: jest.Mock; save: jest.Mock };
  offers: { exists: jest.Mock; find: jest.Mock; save: jest.Mock; create: jest.Mock };
  riders: { findOne: jest.Mock; save: jest.Mock; createQueryBuilder: jest.Mock };
  deliveryRepo: { findOne: jest.Mock; findOneOrFail: jest.Mock; save: jest.Mock };
  riderRepo: { findOne: jest.Mock; save: jest.Mock; update: jest.Mock };
}

function createHarness(): Harness {
  const state: { offer: DeliveryOffer | null; delivery: Delivery | null; candidates: Rider[] } =
    { offer: null, delivery: null, candidates: [] };

  const config = {
    get: jest.fn((key: string, fallback?: unknown) =>
      key === 'OFFER_TTL_SECONDS' ? 300 : fallback,
    ),
  } as unknown as ConfigService;
  const pricing = { distanceKm: jest.fn(() => 1.0) };
  const events = { publishEvent: jest.fn(async () => undefined) };
  const offerExpiry = { schedule: jest.fn(async () => undefined) };

  const riderRepo = {
    update: jest.fn(async () => ({ affected: 1 })),
    findOne: jest.fn(async () => null),
    save: jest.fn(async (rider: Rider) => rider),
  };
  const offerRepo = {
    createQueryBuilder: jest.fn(() => builderChain(() => state.offer)),
    save: jest.fn(async (offer: DeliveryOffer) => offer),
  };
  const deliveryRepo = {
    createQueryBuilder: jest.fn(() => builderChain(() => state.delivery)),
    findOne: jest.fn(async () => null),
    findOneOrFail: jest.fn(async (): Promise<Delivery> => state.delivery as Delivery),
    save: jest.fn(async (delivery: Delivery) => delivery),
  };
  const manager = {
    getRepository: jest.fn((entity: unknown) => {
      if (entity === DeliveryOffer) return offerRepo;
      if (entity === Delivery) return deliveryRepo;
      return riderRepo;
    }),
  };
  const dataSource = {
    transaction: jest.fn(
      async (callback: (m: EntityManager) => Promise<unknown>): Promise<unknown> =>
        callback(manager as unknown as EntityManager),
    ),
  };

  const deliveries = {
    findOne: jest.fn(async () => null),
    save: jest.fn(async (delivery: Delivery) => delivery),
  };
  const offers = {
    exists: jest.fn(async () => false),
    find: jest.fn(async () => []),
    save: jest.fn(async (offer: DeliveryOffer) => offer),
    create: jest.fn((input: Partial<DeliveryOffer>) => input as DeliveryOffer),
  };
  const riders = {
    findOne: jest.fn(async () => null),
    save: jest.fn(async (rider: Rider) => rider),
    createQueryBuilder: jest.fn(() => builderChain(() => state.candidates)),
  };

  const service = new RiderMatchingService(
    pricing as unknown as PricingService,
    config,
    dataSource as unknown as DataSource,
    events as unknown as EventPublisher,
    offerExpiry as unknown as OfferExpiryScheduler,
    deliveries as unknown as Repository<Delivery>,
    offers as unknown as Repository<DeliveryOffer>,
    riders as unknown as Repository<Rider>,
  );

  return {
    service,
    state,
    pricing,
    events,
    offerExpiry,
    deliveries,
    offers,
    riders,
    deliveryRepo,
    riderRepo,
  };
}

const rider = { id: 5, userId: 50 } as Rider;

describe('RiderMatchingService.match', () => {
  it('returns null when the delivery is already assigned', async () => {
    const h = createHarness();
    h.state.delivery = { id: 10, orderId: 7, status: DeliveryStatus.Assigned, riderId: 3 } as Delivery;

    await expect(h.service.match(h.state.delivery)).resolves.toBeNull();
    expect(h.offers.save).not.toHaveBeenCalled();
  });

  it('does not create a second offer while one is already pending', async () => {
    const h = createHarness();
    h.state.delivery = { id: 10, orderId: 7, status: DeliveryStatus.Unassigned, riderId: null } as Delivery;
    h.offers.exists.mockResolvedValue(true);

    await expect(h.service.match(h.state.delivery)).resolves.toBeNull();
    expect(h.offers.save).not.toHaveBeenCalled();
  });

  it('returns null when no eligible rider has a location', async () => {
    const h = createHarness();
    h.state.delivery = { id: 10, orderId: 7, status: DeliveryStatus.Unassigned, riderId: null } as Delivery;
    h.state.candidates = [];

    await expect(h.service.match(h.state.delivery)).resolves.toBeNull();
    expect(h.offers.save).not.toHaveBeenCalled();
  });

  it('creates a pending offer for the nearest rider and schedules expiry', async () => {
    const h = createHarness();
    h.state.delivery = {
      id: 10,
      orderId: 7,
      status: DeliveryStatus.Unassigned,
      riderId: null,
      pickupLatitude: '14.5995',
      pickupLongitude: '120.9842',
    } as Delivery;
    h.state.candidates = [
      { id: 1, userId: 11, currentLatitude: '14.6000', currentLongitude: '121.0000' } as Rider,
      { id: 5, userId: 50, currentLatitude: '14.6100', currentLongitude: '121.0100' } as Rider,
    ];
    h.pricing.distanceKm.mockImplementation(
      (_fromLat?: number | null, _fromLng?: number | null, toLat?: number | null) =>
        Number(toLat) === 14.61 ? 2 : 5,
    );

    const offer = await h.service.match(h.state.delivery);

    expect(offer?.riderId).toBe(5);
    expect(offer?.status).toBe(DeliveryOfferStatus.Pending);
    expect(h.offerExpiry.schedule).toHaveBeenCalledWith(
      { deliveryId: 10, offerId: offer?.id, riderId: 5 },
      offer?.expiresAt,
    );
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.RealtimeFeed, EventType.RealtimeEmit,
      expect.objectContaining({ rooms: ['user:50'], event: 'delivery.offered',
        data: expect.objectContaining({ offerId: offer?.id, deliveryId: 10 }) }),
      expect.any(String),
    );
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.NotificationJobs, EventType.NotificationCreate,
      expect.objectContaining({ sourceKey: `rider-offer-${offer?.id}`, userId: 50,
        type: 'delivery.offered', data: expect.objectContaining({ deliveryId: 10 }) }),
      expect.any(String),
    );
    // Offer bookkeeping must not be sent to order-service's domain queue.
    expect(h.events.publishEvent).not.toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.DispatchOfferCreated,
      expect.anything(),
      expect.anything(),
    );
  });

  it('matches a delivery for an order by order id', async () => {
    const h = createHarness();
    h.state.delivery = { id: 10, orderId: 7, status: DeliveryStatus.Unassigned, riderId: null } as Delivery;
    h.deliveries.findOne.mockResolvedValue(h.state.delivery);
    h.state.candidates = [{ id: 5, userId: 50 } as Rider];

    const offer = await h.service.matchForOrder(7);

    expect(offer?.riderId).toBe(5);
    expect(h.deliveries.findOne).toHaveBeenCalledWith({ where: { orderId: 7 } });
  });
});

describe('RiderMatchingService.accept', () => {
  it('accepts a pending offer, assigns the delivery and marks the rider busy', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 5,
      status: DeliveryOfferStatus.Pending,
      expiresAt: new Date(Date.now() + 60_000),
    } as DeliveryOffer;
    const delivery = {
      id: 10,
      orderId: 7,
      status: DeliveryStatus.Unassigned,
      riderId: null,
    } as Delivery;
    h.state.offer = offer;
    h.state.delivery = delivery;
    h.riderRepo.findOne.mockResolvedValue({ id: 5, status: RiderStatus.Online } as Rider);

    const result = await h.service.accept(offer, rider);

    expect(result.status).toBe(DeliveryStatus.Assigned);
    expect(result.riderId).toBe(5);
    expect(offer.status).toBe(DeliveryOfferStatus.Accepted);
    expect(h.riderRepo.update).toHaveBeenCalledWith({ id: 5 }, { status: RiderStatus.Busy });
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.DeliveryAssigned,
      expect.objectContaining({ deliveryId: 10, riderId: 5 }),
      expect.any(String),
    );
  });

  it('rejects an offer that belongs to another rider', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 6,
      status: DeliveryOfferStatus.Pending,
      expiresAt: new Date(Date.now() + 60_000),
    } as DeliveryOffer;
    h.state.offer = offer;

    await expect(h.service.accept(offer, rider)).rejects.toThrow(
      'This offer does not belong to you.',
    );
  });

  it('rejects an offer that is no longer pending', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 5,
      status: DeliveryOfferStatus.Rejected,
      expiresAt: new Date(Date.now() + 60_000),
    } as DeliveryOffer;
    h.state.offer = offer;

    await expect(h.service.accept(offer, rider)).rejects.toThrow(
      'This offer is no longer available.',
    );
  });

  it('fails when the delivery was already assigned (lost race)', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 5,
      status: DeliveryOfferStatus.Pending,
      expiresAt: new Date(Date.now() + 60_000),
    } as DeliveryOffer;
    h.state.offer = offer;
    h.state.delivery = {
      id: 10,
      orderId: 7,
      status: DeliveryStatus.Assigned,
      riderId: 3,
    } as Delivery;

    await expect(h.service.accept(offer, rider)).rejects.toThrow(
      'This delivery has already been assigned to another rider.',
    );
  });

  it('fails when the rider is busy or suspended', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 5,
      status: DeliveryOfferStatus.Pending,
      expiresAt: new Date(Date.now() + 60_000),
    } as DeliveryOffer;
    h.state.offer = offer;
    h.state.delivery = { id: 10, orderId: 7, status: DeliveryStatus.Unassigned, riderId: null } as Delivery;
    h.riderRepo.findOne.mockResolvedValue({ id: 5, status: RiderStatus.Busy } as Rider);

    await expect(h.service.accept(offer, rider)).rejects.toThrow(
      'You cannot accept a delivery while busy or suspended.',
    );
  });

  it('expires a stale offer and re-matches the delivery', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 5,
      status: DeliveryOfferStatus.Pending,
      expiresAt: new Date(Date.now() - 1000),
    } as DeliveryOffer;
    const delivery = {
      id: 10,
      orderId: 7,
      status: DeliveryStatus.Unassigned,
      riderId: null,
    } as Delivery;
    h.state.offer = offer;
    h.state.delivery = delivery;
    h.deliveryRepo.findOne.mockResolvedValue(delivery);
    const matchSpy = jest.spyOn(h.service, 'match').mockResolvedValue(null);

    await expect(h.service.accept(offer, rider)).rejects.toThrow('This offer has expired.');

    expect(offer.status).toBe(DeliveryOfferStatus.Expired);
    expect(matchSpy).toHaveBeenCalledWith(delivery);
  });
});

describe('RiderMatchingService.reject', () => {
  it('rejects the offer and matches the next candidate', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 5,
      status: DeliveryOfferStatus.Pending,
    } as DeliveryOffer;
    const delivery = {
      id: 10,
      orderId: 7,
      status: DeliveryStatus.Unassigned,
      riderId: null,
    } as Delivery;
    h.state.offer = offer;
    h.state.delivery = delivery;
    h.deliveries.findOne.mockResolvedValue(delivery);
    const nextSpy = jest.spyOn(h.service, 'matchNext').mockResolvedValue(null);

    const result = await h.service.reject(offer, rider);

    expect(result.status).toBe(DeliveryOfferStatus.Rejected);
    expect(result.respondedAt).toBeInstanceOf(Date);
    expect(nextSpy).toHaveBeenCalledWith(delivery);
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.RealtimeFeed,
      EventType.RealtimeEmit,
      expect.objectContaining({ rooms: ['user:50'], event: 'offer.updated',
        data: expect.objectContaining({ deliveryId: 10, offerId: 20 }) }),
      expect.any(String),
    );
  });

  it('rejects an offer that does not belong to the rider', async () => {
    const h = createHarness();
    const offer = {
      id: 20,
      deliveryId: 10,
      riderId: 6,
      status: DeliveryOfferStatus.Pending,
    } as DeliveryOffer;
    h.state.offer = offer;

    await expect(h.service.reject(offer, rider)).rejects.toThrow(
      'This offer does not belong to you.',
    );
  });
});
