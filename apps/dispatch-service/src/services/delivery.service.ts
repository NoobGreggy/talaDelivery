import { Injectable } from '@nestjs/common';
import { DomainError, requestContext } from '@taladelivery/common';
import { DeliveryOfferStatus, DeliveryStatus, RiderStatus } from '@taladelivery/contracts';
import { EventType, EventPublisher, QueueName } from '@taladelivery/events';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Delivery } from '../entities/delivery.entity';
import { Rider } from '../entities/rider.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { RiderCoinsService } from './rider-coins.service';

/**
 * Delivery state transitions for riders and admins.
 * Ported 1:1 from Laravel DeliveryService (messages + timestamps).
 * Order-status side effects happen in order-service via delivery.* events.
 */
@Injectable()
export class DeliveryService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly events: EventPublisher,
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
    @InjectRepository(Rider) private readonly riders: Repository<Rider>,
    @InjectRepository(DeliveryOffer) private readonly offers: Repository<DeliveryOffer>,
    private readonly coins: RiderCoinsService,
  ) {}

  /** Admin manual assignment (mirrors DeliveryService::assign). */
  async assign(delivery: Delivery, rider: Rider): Promise<Delivery> {
    if (delivery.riderId !== null || delivery.status !== DeliveryStatus.Unassigned) {
      throw new DomainError('A rider has already been assigned to this delivery.');
    }

    const riderRow = await this.riders.findOne({ where: { id: rider.id } });
    if (riderRow === null || riderRow.status === RiderStatus.Suspended) {
      throw new DomainError('This user is not an active rider.');
    }

    const updated = await this.dataSource.transaction(async (manager): Promise<Delivery> => {
      const deliveryRow = await manager
        .getRepository(Delivery)
        .createQueryBuilder('delivery')
        .setLock('pessimistic_write')
        .where('delivery.id = :id', { id: delivery.id })
        .getOne();

      if (deliveryRow === null) {
        throw new DomainError('This delivery is no longer available.');
      }

      deliveryRow.riderId = rider.id;
      deliveryRow.status = DeliveryStatus.Assigned;
      deliveryRow.assignedAt = new Date();
      await manager.getRepository(Delivery).save(deliveryRow);

      await manager.getRepository(Rider).update({ id: rider.id }, { status: RiderStatus.Busy });

      return deliveryRow;
    });

    const correlationId = this.correlationId();
    await this.events.publishEvent(
      QueueName.DeliveryEvents,
      EventType.DeliveryAssigned,
      {
        deliveryId: updated.id,
        orderId: updated.orderId,
        riderId: rider.id,
        status: DeliveryStatus.Assigned,
      },
      correlationId,
    );

    await this.pushDelivery(updated, rider);
    return updated;
  }

  /** Rider arrives at the store (ASSIGNED -> ACCEPTED). */
  async arrived(delivery: Delivery, rider: Rider): Promise<Delivery> {
    this.assertAssignedRider(delivery, rider);
    this.assertStatus(delivery, DeliveryStatus.Assigned);

    delivery.status = DeliveryStatus.Accepted;
    delivery.acceptedAt = new Date();
    await this.deliveries.save(delivery);

    await this.events.publishEvent(
      QueueName.DeliveryEvents,
      EventType.RiderArrived,
      { deliveryId: delivery.id, orderId: delivery.orderId },
      this.correlationId(),
    );
    await this.pushDelivery(delivery, rider);
    return delivery;
  }

  /** Rider picks up the order (ACCEPTED -> PICKED_UP). */
  async pickup(delivery: Delivery, rider: Rider): Promise<Delivery> {
    this.assertAssignedRider(delivery, rider);
    this.assertStatus(delivery, DeliveryStatus.Accepted);

    delivery.status = DeliveryStatus.PickedUp;
    delivery.pickedUpAt = new Date();
    await this.deliveries.save(delivery);

    await this.events.publishEvent(
      QueueName.DeliveryEvents,
      EventType.DeliveryPickedUp,
      { deliveryId: delivery.id, orderId: delivery.orderId },
      this.correlationId(),
    );
    await this.pushDelivery(delivery, rider);
    return delivery;
  }

  /** Rider starts the trip to the customer (PICKED_UP -> IN_TRANSIT). */
  async start(delivery: Delivery, rider: Rider): Promise<Delivery> {
    this.assertAssignedRider(delivery, rider);
    this.assertStatus(delivery, DeliveryStatus.PickedUp);

    delivery.status = DeliveryStatus.InTransit;
    delivery.startedAt = new Date();
    await this.deliveries.save(delivery);

    await this.events.publishEvent(
      QueueName.DeliveryEvents,
      EventType.DeliveryInTransit,
      { deliveryId: delivery.id, orderId: delivery.orderId },
      this.correlationId(),
    );
    await this.pushDelivery(delivery, rider);
    return delivery;
  }

  /** Rider completes the delivery (IN_TRANSIT|PICKED_UP -> DELIVERED). */
  async complete(delivery: Delivery, rider: Rider): Promise<Delivery> {
    this.assertAssignedRider(delivery, rider);

    if (
      delivery.status !== DeliveryStatus.InTransit &&
      delivery.status !== DeliveryStatus.PickedUp
    ) {
      throw new DomainError('Delivery can only be completed after the order has been picked up.');
    }

    const updated = await this.dataSource.transaction(async (manager): Promise<Delivery> => {
      const row = await manager
        .getRepository(Delivery)
        .createQueryBuilder('delivery')
        .setLock('pessimistic_write')
        .where('delivery.id = :id', { id: delivery.id })
        .getOne();

      if (row === null) {
        throw new DomainError('This delivery is no longer available.');
      }

      this.assertAssignedRider(row, rider);
      if (row.status !== DeliveryStatus.InTransit && row.status !== DeliveryStatus.PickedUp) {
        throw new DomainError('Delivery can only be completed after the order has been picked up.');
      }
      await this.coins.deduct(manager, row);
      row.status = DeliveryStatus.Delivered;
      row.deliveredAt = new Date();
      await manager.getRepository(Delivery).save(row);

      if (row.riderId !== null) {
        await manager
          .getRepository(Rider)
          .update({ id: row.riderId }, { status: RiderStatus.Online });
      }

      return row;
    });

    const correlationId = this.correlationId();
    const delivered = {
      deliveryId: updated.id,
      orderId: updated.orderId,
      riderId: updated.riderId,
    };
    await this.events.publishEvent(
      QueueName.DeliveryEvents,
      EventType.DeliveryDelivered,
      delivered,
      correlationId,
    );
    // payment-service captures the COD payment on delivery, but it is not the
    // owner of `delivery-events` — fan out to its own queue.
    await this.events.publishEvent(
      QueueName.PaymentJobs,
      EventType.DeliveryDelivered,
      delivered,
      correlationId,
    );
    void this.coins.flushAlerts();
    await this.pushDelivery(updated, rider);
    return updated;
  }

  /** Admin/order-initiated cancellation. */
  async cancel(delivery: Delivery, cancelledBy: string, reason?: string | null): Promise<Delivery> {
    const updated = await this.dataSource.transaction(async (manager): Promise<Delivery> => {
      const row = await manager
        .getRepository(Delivery)
        .createQueryBuilder('delivery')
        .setLock('pessimistic_write')
        .where('delivery.id = :id', { id: delivery.id })
        .getOne();

      if (row === null) {
        throw new DomainError('This delivery is no longer available.');
      }

      row.status = DeliveryStatus.Cancelled;
      row.cancelledBy = cancelledBy;
      row.cancellationReason = reason ?? null;
      row.cancelledAt = new Date();
      await manager.getRepository(Delivery).save(row);

      if (row.riderId !== null) {
        await manager
          .getRepository(Rider)
          .update({ id: row.riderId }, { status: RiderStatus.Online });
      }

      return row;
    });

    await this.expirePendingOffers(updated.id);
    await this.events.publishEvent(
      QueueName.DeliveryEvents,
      EventType.DeliveryCancelled,
      {
        deliveryId: updated.id,
        orderId: updated.orderId,
        cancelledBy,
        reason: reason ?? null,
      },
      this.correlationId(),
    );
    await this.pushDelivery(updated);
    return updated;
  }

  /** Expires every pending offer for a delivery (admin manual assign flow). */
  async expirePendingOffers(deliveryId: number): Promise<void> {
    const pending = await this.offers.find({
      where: { deliveryId, status: DeliveryOfferStatus.Pending },
    });
    await this.offers.update(
      { deliveryId, status: DeliveryOfferStatus.Pending },
      { status: DeliveryOfferStatus.Expired, respondedAt: new Date() },
    );
    for (const offer of pending) {
      const rider = await this.riders.findOne({ where: { id: offer.riderId } });
      if (!rider?.userId) continue;
      await this.events.publishEvent(
        QueueName.RealtimeFeed,
        EventType.RealtimeEmit,
        {
          rooms: [`user:${rider.userId}`],
          event: 'offer.updated',
          data: { offerId: offer.id, deliveryId, status: DeliveryOfferStatus.Expired },
        },
        this.correlationId(),
      );
    }
  }

  private assertAssignedRider(delivery: Delivery, rider: Rider): void {
    if (delivery.riderId === null || delivery.riderId !== rider.id) {
      throw new DomainError('Only the assigned rider can update this delivery.');
    }
  }

  private async pushDelivery(delivery: Delivery, rider?: Rider): Promise<void> {
    const recipient =
      rider ??
      (delivery.riderId === null
        ? null
        : await this.riders.findOne({ where: { id: delivery.riderId } }));
    if (!recipient?.userId) return;
    await this.events.publishEvent(
      QueueName.RealtimeFeed,
      EventType.RealtimeEmit,
      {
        rooms: [`user:${recipient.userId}`],
        event: 'delivery.updated',
        data: { deliveryId: delivery.id, orderId: delivery.orderId, status: delivery.status },
      },
      this.correlationId(),
    );
  }

  private assertStatus(delivery: Delivery, expected: string): void {
    if (delivery.status !== expected) {
      throw new DomainError(`Delivery must be ${expected} to perform this action.`);
    }
  }

  private correlationId(): string {
    return requestContext().correlationId;
  }
}
