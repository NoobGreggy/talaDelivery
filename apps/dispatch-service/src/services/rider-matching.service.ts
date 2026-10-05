import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DomainError, requestContext } from '@taladelivery/common';
import { DeliveryOfferStatus, DeliveryStatus, RiderStatus } from '@taladelivery/contracts';
import { EventType, EventPublisher, QueueName } from '@taladelivery/events';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { Rider } from '../entities/rider.entity';
import { PricingService } from './pricing.service';
import { OfferExpiryScheduler } from './offer-expiry-scheduler.service';

/**
 * Nearest-rider matching + offer accept/reject with pessimistic locking.
 * Ported 1:1 from Laravel RiderMatchingService.
 */
@Injectable()
export class RiderMatchingService {
  private readonly logger = new Logger(RiderMatchingService.name);

  constructor(
    private readonly pricing: PricingService,
    private readonly config: ConfigService,
    private readonly dataSource: DataSource,
    private readonly events: EventPublisher,
    private readonly offerExpiry: OfferExpiryScheduler,
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
    @InjectRepository(DeliveryOffer) private readonly offers: Repository<DeliveryOffer>,
    @InjectRepository(Rider) private readonly riders: Repository<Rider>,
  ) {}

  get offerTtlSeconds(): number {
    return Number(this.config.get('OFFER_TTL_SECONDS', 300));
  }

  async match(delivery: Delivery): Promise<DeliveryOffer | null> {
    if (delivery.status !== DeliveryStatus.Unassigned || delivery.riderId !== null) {
      return null;
    }

    const hasPendingOffer = await this.offers.exists({
      where: { deliveryId: delivery.id, status: DeliveryOfferStatus.Pending },
    });
    if (hasPendingOffer) {
      return null;
    }

    const alreadyOffered = (
      await this.offers.find({ where: { deliveryId: delivery.id }, select: ['riderId'] })
    ).map((offer) => offer.riderId);

    const candidates = await this.riders
      .createQueryBuilder('rider')
      .where('rider.status = :status', { status: RiderStatus.Online })
      .andWhere('rider.current_latitude IS NOT NULL')
      .andWhere('rider.current_longitude IS NOT NULL')
      .getMany();

    const pickupLat = Number.parseFloat(delivery.pickupLatitude ?? '');
    const pickupLng = Number.parseFloat(delivery.pickupLongitude ?? '');

    const eligible = candidates.filter(
      (rider): boolean => !alreadyOffered.includes(rider.id) && rider.userId !== undefined,
    );
    const nearest = eligible
      .sort(
        (a, b) =>
          this.pricing.distanceKm(
            pickupLat,
            pickupLng,
            Number.parseFloat(a.currentLatitude ?? '0'),
            Number.parseFloat(a.currentLongitude ?? '0'),
          ) -
          this.pricing.distanceKm(
            pickupLat,
            pickupLng,
            Number.parseFloat(b.currentLatitude ?? '0'),
            Number.parseFloat(b.currentLongitude ?? '0'),
          ),
      )
      .find(() => true);

    if (nearest === undefined) {
      return null;
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + this.offerTtlSeconds * 1000);

    const offer = await this.offers.save(
      this.offers.create({
        deliveryId: delivery.id,
        riderId: nearest.id,
        status: DeliveryOfferStatus.Pending,
        offeredAt: now,
        expiresAt,
      }),
    );

    await this.offerExpiry.schedule(
      {
        deliveryId: delivery.id,
        offerId: offer.id,
        riderId: nearest.id,
      },
      expiresAt,
    );

    await this.pushOffer(offer, nearest.userId, 'delivery.offered');
    await this.events.publishEvent(
      QueueName.NotificationJobs,
      EventType.NotificationCreate,
      {
        sourceKey: `rider-offer-${offer.id}`,
        userId: nearest.userId,
        type: 'delivery.offered',
        title: 'New delivery offer',
        body: 'A nearby delivery is ready for pickup. Open the app to review your offer.',
        data: { offerId: offer.id, deliveryId: delivery.id, expiresAt: expiresAt.toISOString() },
      },
      this.correlationId(),
    );
    this.logger.log(`Offered delivery #${delivery.id} to rider #${nearest.id}`);
    return offer;
  }

  async accept(offer: DeliveryOffer, rider: Rider): Promise<Delivery> {
    const updated = await this.dataSource.transaction(async (manager): Promise<Delivery> => {
      const offerRepo = manager.getRepository(DeliveryOffer);
      const deliveryRepo = manager.getRepository(Delivery);
      const riderRepo = manager.getRepository(Rider);

      const lockedOffer = await offerRepo
        .createQueryBuilder('offer')
        .setLock('pessimistic_write')
        .where('offer.id = :id', { id: offer.id })
        .getOne();

      if (lockedOffer === null) {
        throw new DomainError('This offer is no longer available.');
      }

      if (lockedOffer.riderId !== rider.id) {
        throw new DomainError('This offer does not belong to you.');
      }

      if (lockedOffer.status !== DeliveryOfferStatus.Pending) {
        throw new DomainError('This offer is no longer available.');
      }

      if (lockedOffer.expiresAt !== null && new Date() >= lockedOffer.expiresAt) {
        lockedOffer.status = DeliveryOfferStatus.Expired;
        lockedOffer.respondedAt = new Date();
        await offerRepo.save(lockedOffer);

        const delivery = await deliveryRepo.findOne({
          where: { id: lockedOffer.deliveryId },
        });
        if (delivery !== null) {
          await this.match(delivery);
        }

        throw new DomainError('This offer has expired.');
      }

      const delivery = await deliveryRepo
        .createQueryBuilder('delivery')
        .setLock('pessimistic_write')
        .where('delivery.id = :id', { id: lockedOffer.deliveryId })
        .getOne();

      if (delivery === null) {
        throw new DomainError('This delivery is no longer available.');
      }

      if (delivery.riderId !== null || delivery.status !== DeliveryStatus.Unassigned) {
        throw new DomainError('This delivery has already been assigned to another rider.');
      }

      const riderRow = await riderRepo.findOne({ where: { id: rider.id } });
      if (
        riderRow === null ||
        riderRow.status === RiderStatus.Busy ||
        riderRow.status === RiderStatus.Suspended
      ) {
        throw new DomainError('You cannot accept a delivery while busy or suspended.');
      }

      lockedOffer.status = DeliveryOfferStatus.Accepted;
      lockedOffer.respondedAt = new Date();
      await offerRepo.save(lockedOffer);

      delivery.riderId = rider.id;
      delivery.status = DeliveryStatus.Assigned;
      delivery.assignedAt = new Date();
      await deliveryRepo.save(delivery);

      riderRow.status = RiderStatus.Busy;
      await riderRepo.update({ id: rider.id }, { status: RiderStatus.Busy });

      return deliveryRepo.findOneOrFail({ where: { id: delivery.id } });
    });
    // Publish after commit so a pushed event can be followed by a fresh GET.
    await this.events.publishEvent(
      QueueName.DeliveryEvents,
      EventType.DeliveryAssigned,
      {
        deliveryId: updated.id,
        orderId: updated.orderId,
        riderId: rider.id,
        status: DeliveryStatus.Assigned,
      },
      this.correlationId(),
    );
    await this.events.publishEvent(
      QueueName.RealtimeFeed,
      EventType.RealtimeEmit,
      {
        rooms: [`user:${rider.userId}`],
        event: 'delivery.updated',
        data: { deliveryId: updated.id, status: updated.status },
      },
      this.correlationId(),
    );
    return updated;
  }

  async reject(offer: DeliveryOffer, rider: Rider): Promise<DeliveryOffer> {
    const updated = await this.dataSource.transaction(async (manager): Promise<DeliveryOffer> => {
      const offerRepo = manager.getRepository(DeliveryOffer);

      const lockedOffer = await offerRepo
        .createQueryBuilder('offer')
        .setLock('pessimistic_write')
        .where('offer.id = :id', { id: offer.id })
        .getOne();

      if (lockedOffer === null) {
        throw new DomainError('This offer is no longer available.');
      }

      if (lockedOffer.riderId !== rider.id) {
        throw new DomainError('This offer does not belong to you.');
      }

      if (lockedOffer.status !== DeliveryOfferStatus.Pending) {
        throw new DomainError('This offer is no longer available.');
      }

      lockedOffer.status = DeliveryOfferStatus.Rejected;
      lockedOffer.respondedAt = new Date();
      await offerRepo.save(lockedOffer);

      return lockedOffer;
    });
    await this.pushOffer(updated, rider.userId);
    const delivery = await this.deliveries.findOne({ where: { id: updated.deliveryId } });
    if (delivery !== null) await this.matchNext(delivery);
    return updated;
  }

  async matchNext(delivery: Delivery): Promise<DeliveryOffer | null> {
    if (delivery.riderId !== null) {
      return null;
    }
    return this.match(delivery);
  }

  async pushOffer(offer: DeliveryOffer, userId?: number, event = 'offer.updated'): Promise<void> {
    const recipient =
      userId ?? (await this.riders.findOne({ where: { id: offer.riderId } }))?.userId;
    if (!recipient) return;
    await this.events.publishEvent(
      QueueName.RealtimeFeed,
      EventType.RealtimeEmit,
      {
        rooms: [`user:${recipient}`],
        event,
        data: {
          offerId: offer.id,
          deliveryId: offer.deliveryId,
          status: offer.status,
          expiresAt: offer.expiresAt?.toISOString() ?? null,
        },
      },
      this.correlationId(),
    );
  }

  /** Entry point for the `order.ready_for_pickup` consumer. */
  async matchForOrder(orderId: number, deliveryId?: number): Promise<DeliveryOffer | null> {
    const delivery = deliveryId
      ? await this.deliveries.findOne({ where: { id: deliveryId, orderId } })
      : await this.deliveries.findOne({ where: { orderId } });
    if (delivery === null) {
      return null;
    }
    return this.match(delivery);
  }

  private correlationId(): string {
    return requestContext().correlationId;
  }
}
