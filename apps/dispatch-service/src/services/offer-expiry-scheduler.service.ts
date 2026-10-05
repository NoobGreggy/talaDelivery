import { Injectable } from '@nestjs/common';
import {
  EventPublisher,
  EventType,
  QueueName,
  buildEnvelope,
} from '@taladelivery/events';

export interface OfferExpiryData {
  deliveryId: number;
  offerId: number;
  riderId: number;
}

/**
 * Schedules a delayed `offer-expiry` job for every created offer
 * (mirrors Laravel ExpireDeliveryOffer::dispatch()->delay($expiresAt)).
 *
 * Enqueues through the shared EventPublisher so the offer-creation path
 * inherits its bounded timeout instead of blocking forever when the broker
 * is unreachable.
 */
@Injectable()
export class OfferExpiryScheduler {
  constructor(private readonly events: EventPublisher) {}

  async schedule(data: OfferExpiryData, expiresAt: Date): Promise<void> {
    const envelope = buildEnvelope(EventType.DispatchOfferExpired, data);
    const delayMs = Math.max(0, expiresAt.getTime() - Date.now());
    await this.events.addJob(QueueName.OfferExpiry, 'expire', envelope as object, {
      jobId: envelope.eventId,
      delayMs,
    });
  }
}
