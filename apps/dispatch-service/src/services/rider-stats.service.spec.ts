import { Repository } from 'typeorm';
import { EventPublisher } from '@taladelivery/events';
import { DeliveryOfferStatus } from '@taladelivery/contracts';
import { RiderService } from './rider.service';
import { RiderMatchingService } from './rider-matching.service';
import { RemoteReferencesService } from './remote-references.service';
import { DispatchResourcesService } from './dispatch-resources.service';
import { Rider } from '../entities/rider.entity';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';

function harness(accepted: number, answered: number) {
  const offerQuery = {
    select: jest.fn().mockReturnThis(),
    addSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    setParameter: jest.fn().mockReturnThis(),
    getRawOne: jest.fn(async () => ({ accepted: String(accepted), answered: String(answered) })),
  };
  const deliveryQuery = {
    select: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getRawMany: jest.fn(async () => [{ commission: '12.50' }]),
  };
  const service = new RiderService(
    {} as Repository<Rider>,
    { createQueryBuilder: () => deliveryQuery } as unknown as Repository<Delivery>,
    { createQueryBuilder: () => offerQuery } as unknown as Repository<DeliveryOffer>,
    {} as RiderMatchingService,
    {} as RemoteReferencesService,
    {} as EventPublisher,
  );
  return { service, offerQuery };
}

describe('Rider performance stats', () => {
  it.each([
    [3, 4, 75],
    [0, 4, 0],
    [4, 4, 100],
    [2, 3, 66.67],
  ])('computes %s accepted of %s answered as %s percent', async (accepted, answered, rate) => {
    const h = harness(accepted, answered);
    const stats = await h.service.stats(5);
    expect(stats).toEqual({
      completed: 1,
      earnings: '12.50',
      acceptanceRate: rate,
      onTimeRate: null,
    });
    expect(h.offerQuery.where).toHaveBeenCalledWith('offer.rider_id = :riderId', { riderId: 5 });
    expect(h.offerQuery.andWhere).toHaveBeenCalledWith('offer.status IN (:...statuses)', {
      statuses: [DeliveryOfferStatus.Accepted, DeliveryOfferStatus.Rejected],
    });
    expect(h.offerQuery.setParameter).toHaveBeenCalledWith(
      'accepted',
      DeliveryOfferStatus.Accepted,
    );
  });
  it('reports no data when no offers have been answered', async () => {
    const h = harness(0, 0);
    expect((await h.service.stats(5)).acceptanceRate).toBeNull();
  });
  it('serializes computed stats into the existing rider profile response', async () => {
    const resources = new DispatchResourcesService(
      { userById: jest.fn(async () => null) } as unknown as RemoteReferencesService,
      {} as Repository<Delivery>,
    );
    const rider = {
      id: 5,
      userId: 50,
      createdAt: new Date(),
      currentLocationUpdatedAt: null,
    } as Rider;
    const result = await resources.riderToJson(rider, {
      stats: await harness(3, 4).service.stats(5),
    });
    expect(result.acceptance_rate).toBe(75);
    expect(result.on_time_rate).toBeNull();
  });
});
