import { Injectable, Logger } from '@nestjs/common';
import { EventType, EventWorkerManager, QueueName } from '@taladelivery/events';
import { PaymentStatus } from '@taladelivery/contracts';
import { OrderService } from '../services/order.service';

interface PaymentStatusPayload {
  paymentId: number;
  orderId: number;
  amount: string;
  method: string;
  status: string;
}

/**
 * Consumes payment-service's outbound `payment-events`.
 *
 * payment-service owns this queue and is its only publisher, so
 * order-service is its single consumer. The order is the customer-facing
 * record, so it — not payment-service — is what mirrors payment state and
 * tells the customer about it.
 */
@Injectable()
export class PaymentEventsConsumer {
  private readonly logger = new Logger(PaymentEventsConsumer.name);

  constructor(
    private readonly workerManager: EventWorkerManager,
    private readonly orders: OrderService,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.workerManager.on(
      QueueName.PaymentEvents,
      async (data: unknown, envelope: { eventType: string }) => {
        const payload = data as PaymentStatusPayload;
        switch (envelope.eventType) {
          case EventType.PaymentCreated:
            await this.orders.handlePaymentChanged(payload, PaymentStatus.Pending);
            break;
          case EventType.PaymentPaid:
            await this.orders.handlePaymentChanged(payload, PaymentStatus.Paid);
            break;
          case EventType.PaymentFailed:
            await this.orders.handlePaymentChanged(payload, PaymentStatus.Failed);
            break;
          case EventType.PaymentRefunded:
            await this.orders.handlePaymentChanged(payload, PaymentStatus.Refunded);
            break;
        }
      },
      {
        eventTypes: [
          EventType.PaymentCreated,
          EventType.PaymentPaid,
          EventType.PaymentFailed,
          EventType.PaymentRefunded,
        ],
      },
    );
    this.logger.log('Payment events consumer registered');
  }
}
