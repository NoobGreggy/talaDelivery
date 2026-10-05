import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeliveryStatus } from '@taladelivery/contracts';
import {
  EventDispatchContext,
  EventType,
  EventWorkerManager,
  QueueName,
} from '@taladelivery/events';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryService } from '../services/delivery.service';
import { RiderMatchingService } from '../services/rider-matching.service';

interface ReadyForPickupPayload {
  orderId: number;
  orderNumber: string;
  deliveryId?: number;
}

interface OrderCancelledPayload {
  orderId: number;
  orderNumber: string;
  cancelledBy?: string;
  reason?: string;
}

/**
 * Dispatch's consumer of order-service events (queue `order-events`):
 *  - `order.ready_for_pickup` → start nearest-rider matching
 *  - `order.cancelled` → cancel the matching delivery (unless already done)
 */
@Injectable()
export class OrderEventsConsumer {
  constructor(
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
    private readonly manager: EventWorkerManager,
    private readonly matching: RiderMatchingService,
    private readonly deliveryService: DeliveryService,
  ) {}

  onModuleInit(): void {
    this.manager.on(
      QueueName.OrderEvents,
      async (data: unknown, envelope: { eventType: string }, _context: EventDispatchContext) => {
        switch (envelope.eventType) {
          case EventType.OrderReadyForPickup: {
            const payload = data as ReadyForPickupPayload;
            await this.matching.matchForOrder(payload.orderId, payload.deliveryId);
            break;
          }
          case EventType.OrderCancelled: {
            await this.handleOrderCancelled(data as OrderCancelledPayload);
            break;
          }
          default:
            break;
        }
      },
      { eventTypes: [EventType.OrderReadyForPickup, EventType.OrderCancelled] },
    );
  }

  private async handleOrderCancelled(payload: OrderCancelledPayload): Promise<void> {
    const delivery = await this.deliveries.findOne({ where: { orderId: payload.orderId } });
    if (delivery === null) {
      return;
    }
    if (
      delivery.status === DeliveryStatus.Delivered ||
      delivery.status === DeliveryStatus.Cancelled
    ) {
      return;
    }
    await this.deliveryService.cancel(
      delivery,
      payload.cancelledBy ?? 'customer',
      payload.reason ?? null,
    );
  }
}