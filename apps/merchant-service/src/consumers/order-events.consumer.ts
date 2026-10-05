import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventType, EventPublisher, EventWorkerManager, QueueName } from '@taladelivery/events';
import { StoreUser } from '../entities/store-user.entity';

interface MerchantOrderPayload {
  orderId: number;
  orderNumber: string;
  storeId: number;
  customerId: number;
  total?: string;
  status?: string;
}

interface StoreCopy {
  type: string;
  title: string;
  body: (payload: MerchantOrderPayload) => string;
}

/**
 * merchant-service's inbound order events.
 *
 * dispatch owns `order-events` and consumes only the types it acts on
 * (`ready_for_pickup`, `cancelled`); merchant-service is a separate consumer
 * and therefore has its own queue. The store's own `store_users` rows give
 * the recipients, so no cross-service lookup is needed.
 */
@Injectable()
export class OrderEventsConsumer {
  private readonly logger = new Logger(OrderEventsConsumer.name);

  constructor(
    @InjectRepository(StoreUser) private readonly storeUsers: Repository<StoreUser>,
    private readonly workerManager: EventWorkerManager,
    private readonly events: EventPublisher,
  ) {}

  private static readonly COPY: Record<string, StoreCopy> = {
    [EventType.OrderCreated]: {
      type: 'order.received',
      title: 'New order received',
      body: (p) => `Order ${p.orderNumber} for ${p.total ?? ''} is waiting to be confirmed.`.trim(),
    },
    [EventType.OrderReadyForPickup]: {
      type: 'order.ready_for_pickup',
      title: 'Order ready for pickup',
      body: (p) => `Order ${p.orderNumber} is ready; a rider is being assigned.`,
    },
    [EventType.OrderCancelled]: {
      type: 'order.cancelled',
      title: 'Order cancelled',
      body: (p) => `Order ${p.orderNumber} was cancelled.`,
    },
    [EventType.OrderDelivered]: {
      type: 'order.delivered',
      title: 'Order delivered',
      body: (p) => `Order ${p.orderNumber} was delivered to the customer.`,
    },
  };

  async onModuleInit(): Promise<void> {
    await this.workerManager.on(
      QueueName.MerchantJobs,
      async (data: unknown, envelope: { eventType: string }) => {
        await this.notifyStore(data as MerchantOrderPayload, envelope.eventType);
      },
      { eventTypes: Object.keys(OrderEventsConsumer.COPY) },
    );
    this.logger.log('Merchant order events consumer registered');
  }

  private async notifyStore(payload: MerchantOrderPayload, eventType: string): Promise<void> {
    const copy = OrderEventsConsumer.COPY[eventType];
    if (copy === undefined) return;

    const members = await this.storeUsers.find({ where: { storeId: payload.storeId } });
    if (members.length === 0) {
      this.logger.warn(
        `Order ${payload.orderNumber}: store ${payload.storeId} has no members to notify`,
      );
      return;
    }
    for (const member of members) {
      await this.events.publishEvent(
        QueueName.NotificationJobs,
        EventType.NotificationCreate,
        {
          userId: member.userId,
          type: copy.type,
          title: copy.title,
          body: copy.body(payload),
          data: {
            orderId: payload.orderId,
            orderNumber: payload.orderNumber,
            storeId: payload.storeId,
            status: payload.status ?? null,
          },
        },
      );
    }
    this.logger.log(
      `Order ${payload.orderNumber} (${eventType}) announced to ${members.length} store member(s)`,
    );
  }
}
