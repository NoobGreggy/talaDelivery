import { DeliveryStatus, RiderStatus } from '@taladelivery/contracts';
import {
  EventType,
  EventPublisher,
  QueueName,
} from '@taladelivery/events';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { Rider } from '../entities/rider.entity';
import { DeliveryService } from './delivery.service';
import { RiderCoinsService } from './rider-coins.service';

function builderChain(getValue: () => unknown): {
  setLock: jest.Mock;
  where: jest.Mock;
  getOne: jest.Mock;
} {
  const chain: {
    setLock: jest.Mock;
    where: jest.Mock;
    getOne: jest.Mock;
  } = {
    setLock: jest.fn(() => chain),
    where: jest.fn(() => chain),
    getOne: jest.fn(async () => getValue()),
  };
  return chain;
}

interface Harness {
  service: DeliveryService;
  events: { publishEvent: jest.Mock };
  deliveries: { save: jest.Mock };
  riders: { findOne: jest.Mock; update: jest.Mock };
  offers: { update: jest.Mock; find: jest.Mock };
  setLocked(delivery: Delivery | null): void;
}

function createHarness(): Harness {
  const state = { locked: null as Delivery | null };
  const events = { publishEvent: jest.fn(async () => undefined) };

  const deliveries = { save: jest.fn(async (delivery: Delivery) => delivery) };
  const riders = {
    findOne: jest.fn(async () => null),
    update: jest.fn(async () => ({ affected: 1 })),
  };
  const offers = { update: jest.fn(async () => ({ affected: 1 })), find: jest.fn(async () => []) };

  const deliveryRepo = {
    createQueryBuilder: jest.fn(() => builderChain(() => state.locked)),
    save: jest.fn(async (delivery: Delivery) => delivery),
  };
  const manager = {
    getRepository: jest.fn((entity: unknown) => {
      if (entity === Delivery) return deliveryRepo;
      if (entity === DeliveryOffer) return offers;
      return riders;
    }),
  };
  const dataSource = {
    transaction: jest.fn(
      async (callback: (m: EntityManager) => Promise<unknown>): Promise<unknown> =>
        callback(manager as unknown as EntityManager),
    ),
  };

  const service = new DeliveryService(
    dataSource as unknown as DataSource,
    events as unknown as EventPublisher,
    deliveries as unknown as Repository<Delivery>,
    riders as unknown as Repository<Rider>,
    offers as unknown as Repository<DeliveryOffer>,
    { deduct: jest.fn(async () => undefined), flushAlerts: jest.fn(async () => undefined) } as unknown as RiderCoinsService,
  );

  return {
    service,
    events,
    deliveries,
    riders,
    offers,
    setLocked: (delivery: Delivery | null) => {
      state.locked = delivery;
    },
  };
}

const rider = { id: 5, userId: 50 } as Rider;

describe('DeliveryService.arrived', () => {
  it('moves an ASSIGNED delivery to ACCEPTED and publishes rider_arrived', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Assigned, riderId: 5 } as Delivery;

    const result = await h.service.arrived(delivery, rider);

    expect(result.status).toBe(DeliveryStatus.Accepted);
    expect(result.acceptedAt).toBeInstanceOf(Date);
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.RealtimeFeed, EventType.RealtimeEmit,
      { rooms: ['user:50'], event: 'delivery.updated',
        data: { deliveryId: 10, orderId: 7, status: 'ACCEPTED' } }, expect.any(String));
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.RiderArrived,
      { deliveryId: 10, orderId: 7 },
      expect.any(String),
    );
  });

  it('rejects a rider that is not assigned to the delivery', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Assigned, riderId: 9 } as Delivery;

    await expect(h.service.arrived(delivery, rider)).rejects.toThrow(
      'Only the assigned rider can update this delivery.',
    );
  });

  it('rejects a transition from the wrong status', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Accepted, riderId: 5 } as Delivery;

    await expect(h.service.arrived(delivery, rider)).rejects.toThrow(
      'Delivery must be ASSIGNED to perform this action.',
    );
  });
});

describe('DeliveryService.pickup', () => {
  it('moves ACCEPTED to PICKED_UP and publishes delivery.picked_up', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Accepted, riderId: 5 } as Delivery;

    const result = await h.service.pickup(delivery, rider);

    expect(result.status).toBe(DeliveryStatus.PickedUp);
    expect(result.pickedUpAt).toBeInstanceOf(Date);
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.DeliveryPickedUp,
      expect.objectContaining({ deliveryId: 10 }),
      expect.any(String),
    );
  });

  it('rejects pickup before arrival', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Assigned, riderId: 5 } as Delivery;

    await expect(h.service.pickup(delivery, rider)).rejects.toThrow(
      'Delivery must be ACCEPTED to perform this action.',
    );
  });
});

describe('DeliveryService.start', () => {
  it('moves PICKED_UP to IN_TRANSIT and publishes delivery.out_for_delivery', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.PickedUp, riderId: 5 } as Delivery;

    const result = await h.service.start(delivery, rider);

    expect(result.status).toBe(DeliveryStatus.InTransit);
    expect(result.startedAt).toBeInstanceOf(Date);
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.DeliveryInTransit,
      expect.objectContaining({ deliveryId: 10 }),
      expect.any(String),
    );
  });

  it('rejects starting while the order has not been picked up', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Accepted, riderId: 5 } as Delivery;

    await expect(h.service.start(delivery, rider)).rejects.toThrow(
      'Delivery must be PICKED_UP to perform this action.',
    );
  });
});

describe('DeliveryService.complete', () => {
  it('rejects a stale completion request when the locked delivery is already completed', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.InTransit, riderId: 5 } as Delivery;
    h.setLocked({ ...delivery, status: DeliveryStatus.Delivered });
    await expect(h.service.complete(delivery, rider)).rejects.toThrow('Delivery can only be completed');
    expect(h.events.publishEvent).not.toHaveBeenCalled();
    expect(h.riders.update).not.toHaveBeenCalled();
  });

  it('rechecks the assigned rider inside the locked transaction', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.InTransit, riderId: 5 } as Delivery;
    h.setLocked({ ...delivery, riderId: 9 });
    await expect(h.service.complete(delivery, rider)).rejects.toThrow('Only the assigned rider');
    expect(h.events.publishEvent).not.toHaveBeenCalled();
  });
  it('completes an IN_TRANSIT delivery and frees the rider', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.InTransit, riderId: 5 } as Delivery;
    h.setLocked({ ...delivery });

    const result = await h.service.complete(delivery, rider);

    expect(result.status).toBe(DeliveryStatus.Delivered);
    expect(result.deliveredAt).toBeInstanceOf(Date);
    expect(h.riders.update).toHaveBeenCalledWith({ id: 5 }, { status: RiderStatus.Online });
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.DeliveryDelivered,
      expect.objectContaining({ deliveryId: 10, riderId: 5 }),
      expect.any(String),
    );
  });

  it('allows completion straight from PICKED_UP', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.PickedUp, riderId: 5 } as Delivery;
    h.setLocked({ ...delivery });

    const result = await h.service.complete(delivery, rider);

    expect(result.status).toBe(DeliveryStatus.Delivered);
  });

  it('rejects completion before pickup', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Assigned, riderId: 5 } as Delivery;

    await expect(h.service.complete(delivery, rider)).rejects.toThrow(
      'Delivery can only be completed after the order has been picked up.',
    );
    expect(h.events.publishEvent).not.toHaveBeenCalled();
  });
});

describe('DeliveryService.cancel', () => {
  it('cancels the delivery, frees the rider and publishes delivery.cancelled', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Assigned, riderId: 5 } as Delivery;
    h.setLocked({ ...delivery });
    h.riders.findOne.mockResolvedValue(rider);

    const result = await h.service.cancel(delivery, 'customer', 'Changed my mind');

    expect(result.status).toBe(DeliveryStatus.Cancelled);
    expect(result.cancelledBy).toBe('customer');
    expect(result.cancellationReason).toBe('Changed my mind');
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.RealtimeFeed, EventType.RealtimeEmit,
      { rooms: ['user:50'], event: 'delivery.updated',
        data: { deliveryId: 10, orderId: 7, status: 'CANCELLED' } }, expect.any(String));
    expect(h.riders.update).toHaveBeenCalledWith({ id: 5 }, { status: RiderStatus.Online });
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.DeliveryCancelled,
      expect.objectContaining({
        deliveryId: 10,
        orderId: 7,
        cancelledBy: 'customer',
        reason: 'Changed my mind',
      }),
      expect.any(String),
    );
  });
});

describe('DeliveryService.assign (admin)', () => {
  it('assigns an unassigned delivery to an active rider', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Unassigned, riderId: null } as Delivery;
    h.setLocked({ ...delivery });
    h.riders.findOne.mockResolvedValue({ id: 5, status: RiderStatus.Online } as Rider);

    const result = await h.service.assign(delivery, rider);

    expect(result.riderId).toBe(5);
    expect(result.status).toBe(DeliveryStatus.Assigned);
    expect(result.assignedAt).toBeInstanceOf(Date);
    expect(h.riders.update).toHaveBeenCalledWith({ id: 5 }, { status: RiderStatus.Busy });
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.DeliveryEvents,
      EventType.DeliveryAssigned,
      expect.objectContaining({ deliveryId: 10, riderId: 5 }),
      expect.any(String),
    );
  });

  it('rejects assignment when a rider is already assigned', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Assigned, riderId: 3 } as Delivery;

    await expect(h.service.assign(delivery, rider)).rejects.toThrow(
      'A rider has already been assigned to this delivery.',
    );
  });

  it('rejects assignment when the rider is suspended', async () => {
    const h = createHarness();
    const delivery = { id: 10, orderId: 7, status: DeliveryStatus.Unassigned, riderId: null } as Delivery;
    h.riders.findOne.mockResolvedValue({ id: 5, status: RiderStatus.Suspended } as Rider);

    await expect(h.service.assign(delivery, rider)).rejects.toThrow(
      'This user is not an active rider.',
    );
  });
});

describe('DeliveryService.expirePendingOffers', () => {
  it('notifies pending riders when an order is cancelled or assigned manually', async () => {
    const h = createHarness();
    h.offers.find.mockResolvedValue([{ id: 20, riderId: 5 }]);
    h.riders.findOne.mockResolvedValue(rider);
    await h.service.expirePendingOffers(10);
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.RealtimeFeed, EventType.RealtimeEmit,
      { rooms: ['user:50'], event: 'offer.updated',
        data: { offerId: 20, deliveryId: 10, status: 'EXPIRED' } }, expect.any(String));
  });
  it('expires every pending offer of a delivery', async () => {
    const h = createHarness();
    await h.service.expirePendingOffers(10);
    expect(h.offers.update).toHaveBeenCalledWith(
      { deliveryId: 10, status: 'PENDING' },
      expect.objectContaining({ status: 'EXPIRED' }),
    );
  });
});
