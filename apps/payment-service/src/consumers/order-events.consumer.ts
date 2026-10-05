import { Injectable } from '@nestjs/common';
import {
  EventDispatchContext,
  EventType,
  EventWorkerManager,
  QueueName,
} from '@taladelivery/events';
import {
  OrderCreatedPayload,
  PaymentService,
} from '../services/payment.service';

/**
 * Payment-service consumer of order-service events (queue `order-events`):
 * `order.created` → ensure a PENDING COD payment exists for the order
 * (authoritative amount comes from the event's `total`). Idempotent: a
 * redelivered `order.created` returns the existing row and never re-publishes
 * `payment.created`.
 */
@Injectable()
export class OrderEventsConsumer {
  constructor(
    private readonly manager: EventWorkerManager,
    private readonly payments: PaymentService,
  ) {}

  onModuleInit(): void {
    this.manager.on(
      // `payment-jobs`, not `order-events`: dispatch-service owns
      // `order-events`, and two consumers on one BullMQ queue destroy every
      // event whose type the claiming worker does not handle.
      QueueName.PaymentJobs,
      async (data: unknown, _envelope, _context: EventDispatchContext) => {
        await this.payments.ensureForOrder(data as OrderCreatedPayload);
      },
      { eventTypes: [EventType.OrderCreated] },
    );
  }
}