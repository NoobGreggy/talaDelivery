import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { requestContext } from '@taladelivery/common';
import {
  DeliveryOfferStatus,
  DeliveryStatus,
} from '@taladelivery/contracts';
import {
  EventDispatchContext,
  EventType,
  EventPublisher,
  EventWorkerManager,
  QueueName,
} from '@taladelivery/events';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { RiderMatchingService } from '../services/rider-matching.service';
import type { OfferExpiryData } from '../services/offer-expiry-scheduler.service';

/**
 * Consumes delayed `offer-expiry` jobs (scheduled by OfferExpiryScheduler at
 * offer creation). Marks pending offers EXPIRED, publishes
 * `dispatch.offer_expired`, and — when no other rider is pending — runs the
 * next matching round for the delivery (mirrors Laravel ExpireDeliveryOffer).
 */
@Injectable()
export class OfferExpiryConsumer {
  private readonly logger = new Logger(OfferExpiryConsumer.name);

  constructor(
    @InjectRepository(DeliveryOffer)
    private readonly offers: Repository<DeliveryOffer>,
    @InjectRepository(Delivery)
    private readonly deliveries: Repository<Delivery>,
    private readonly manager: EventWorkerManager,
    private readonly matching: RiderMatchingService,
    private readonly events: EventPublisher,
  ) {}

  onModuleInit(): void {
    this.manager.on(
      QueueName.OfferExpiry,
      async (data: unknown, _envelope: { eventType: string }, _context: EventDispatchContext) => {
        await this.handleExpiry(data as OfferExpiryData);
      },
      { eventTypes: [EventType.DispatchOfferExpired] },
    );
  }

  private async handleExpiry(data: OfferExpiryData): Promise<void> {
    const offer = await this.offers.findOne({ where: { id: data.offerId } });
    if (offer === null || offer.status !== DeliveryOfferStatus.Pending) {
      return;
    }

    offer.status = DeliveryOfferStatus.Expired;
    offer.respondedAt = new Date();
    await this.offers.save(offer);

    await this.matching.pushOffer(offer);

    const delivery = await this.deliveries.findOne({
      where: { id: offer.deliveryId },
    });
    if (
      delivery !== null &&
      delivery.status === DeliveryStatus.Unassigned &&
      delivery.riderId === null
    ) {
      await this.matching.matchNext(delivery);
    }
  }
}
