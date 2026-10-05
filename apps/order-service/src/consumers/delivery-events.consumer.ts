import { Injectable, Logger } from '@nestjs/common';
import { EventWorkerManager, EventType, QueueName } from '@taladelivery/events';
import { OrderService } from '../services/order.service';

interface DeliveryEventPayload {
  deliveryId: number;
  orderId: number;
  riderId?: number;
  cancelledBy?: string;
  reason?: string;
}

@Injectable()
export class DeliveryEventsConsumer {
  private readonly logger = new Logger(DeliveryEventsConsumer.name);

  constructor(
    private readonly workerManager: EventWorkerManager,
    private readonly orders: OrderService,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.workerManager.on(
      QueueName.DeliveryEvents,
      // EventWorkerManager hands the handler the *unwrapped* `envelope.data`
      // as its first argument and the full envelope as the second. Reading
      // `event.data` here (as this consumer previously did) yields
      // `undefined` — or, for notification payloads, the inner `data` blob
      // instead of the payload — so every transition was silently skipped.
      async (data: unknown, envelope: { eventType: string }) => {
        const { deliveryId, riderId, cancelledBy, reason } = data as DeliveryEventPayload;
        switch (envelope.eventType) {
          case EventType.DeliveryAssigned:
            await this.orders.handleDeliveryAssigned(deliveryId, riderId ?? 0);
            break;
          case EventType.RiderArrived:
            // The order FSM has no state for "rider at the store" (it goes
            // RIDER_ASSIGNED -> PICKED_UP), so this is acknowledged and
            // dropped deliberately. Registering it keeps it from being
            // discarded as an unroutable event.
            this.logger.debug(`Rider arrived for delivery ${deliveryId}; order status unchanged`);
            break;
          case EventType.DeliveryPickedUp:
            await this.orders.handleDeliveryPickedUp(deliveryId);
            break;
          case EventType.DeliveryInTransit:
            await this.orders.handleDeliveryOutForDelivery(deliveryId);
            break;
          case EventType.DeliveryDelivered:
            await this.orders.handleDeliveryDelivered(deliveryId);
            break;
          case EventType.DeliveryCancelled:
            await this.orders.handleDeliveryCancelled(deliveryId, cancelledBy ?? 'system', reason);
            break;
        }
      },
      {
        eventTypes: [
          EventType.DeliveryAssigned,
          EventType.RiderArrived,
          EventType.DeliveryPickedUp,
          EventType.DeliveryInTransit,
          EventType.DeliveryDelivered,
          EventType.DeliveryCancelled,
        ],
      },
    );
    this.logger.log('Delivery events consumer registered');
  }
}
