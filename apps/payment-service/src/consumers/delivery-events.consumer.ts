import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PaymentMethod, PaymentStatus } from '@taladelivery/contracts';
import {
  EventDispatchContext,
  EventType,
  EventWorkerManager,
  QueueName,
} from '@taladelivery/events';
import { Payment } from '../entities/payment.entity';
import { PaymentService } from '../services/payment.service';

interface DeliveryDeliveredPayload {
  deliveryId: number;
  orderId: number;
  riderId: number;
}

/**
 * Payment-service consumer of dispatch events (queue `delivery-events`):
 * `delivery.delivered` → capture the matching COD payment (PAID) and publish
 * `payment.paid` on `payment-events`. Capture is idempotent (already-PAID
 * payments are no-ops), so redeliveries never emit a second event.
 */
@Injectable()
export class DeliveryEventsConsumer {
  constructor(
    @InjectRepository(Payment) private readonly payments: Repository<Payment>,
    private readonly manager: EventWorkerManager,
    private readonly service: PaymentService,
  ) {}

  onModuleInit(): void {
    this.manager.on(
      // `payment-jobs`, not `delivery-events`: order-service owns
      // `delivery-events`, and two consumers on one BullMQ queue destroy every
      // event whose type the claiming worker does not handle.
      QueueName.PaymentJobs,
      async (data: unknown, _envelope, _context: EventDispatchContext) => {
        await this.handleDelivered(data as DeliveryDeliveredPayload);
      },
      { eventTypes: [EventType.DeliveryDelivered] },
    );
  }

  private async handleDelivered(payload: DeliveryDeliveredPayload): Promise<void> {
    const payment = await this.payments.findOne({
      where: {
        orderId: payload.orderId,
        method: PaymentMethod.Cod,
      },
    });
    if (payment === null || payment.status === PaymentStatus.Paid) {
      return;
    }
    await this.service.capture(payment, 'delivery');
  }
}