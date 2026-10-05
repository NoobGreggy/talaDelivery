import {
  PaymentMethod,
  PaymentStatus,
} from '@taladelivery/contracts';
import {
  EventPublisher,
  EventType,
  EventWorkerManager,
  QueueName,
} from '@taladelivery/events';
import { Repository } from 'typeorm';
import { Payment } from '../entities/payment.entity';
import { PaymentAttempt } from '../entities/payment-attempt.entity';
import { Refund } from '../entities/refund.entity';
import { PaymentService } from '../services/payment.service';
import { DeliveryEventsConsumer } from './delivery-events.consumer';

interface ManagerFake {
  on: jest.Mock;
  handler?: (data: unknown, envelope: { eventType: string }) => Promise<void>;
}

function createManagerFake(): ManagerFake {
  const fake: ManagerFake = {
    on: jest.fn((queue, handler) => {
      fake.handler = handler;
      return fake;
    }),
  };
  return fake;
}

describe('DeliveryEventsConsumer (COD capture on delivery.delivered)', () => {
  it('registers the payment-jobs queue for delivery.delivered', () => {
    const manager = createManagerFake();
    const service = {} as unknown as PaymentService;
    const payments = {} as unknown as Repository<Payment>;

    const consumer = new DeliveryEventsConsumer(payments, manager as unknown as EventWorkerManager, service);
    consumer.onModuleInit();

    // `payment-jobs`, not `delivery-events`: order-service owns
    // `delivery-events`, and two consumers on one queue silently destroy the
    // events the claiming worker does not handle.
    expect(manager.on).toHaveBeenCalledWith(
      QueueName.PaymentJobs,
      expect.any(Function),
      { eventTypes: [EventType.DeliveryDelivered] },
    );
  });

  it('captures the matching COD payment exactly once and publishes payment.paid', async () => {
    const manager = createManagerFake();
    const events = { publishEvent: jest.fn(async () => undefined) };

    // The repository holds one row; capture mutates its status in place.
    const payment = {
      id: 1,
      orderId: 10,
      userId: 5,
      method: PaymentMethod.Cod,
      status: PaymentStatus.Pending,
      amount: '200.00',
    } as Payment;

    const payments = {
      findOne: jest.fn(async () => payment),
      save: jest.fn(async (p: Payment) => p),
    } as unknown as Repository<Payment>;
    const attempts = {
      create: jest.fn((row: Partial<PaymentAttempt>) => row as PaymentAttempt),
      save: jest.fn(async (row: PaymentAttempt) => row),
    };
    const refunds = {
      create: jest.fn((row: Partial<Refund>) => row as Refund),
      save: jest.fn(async (row: Refund) => row),
    };
    const service = new PaymentService(
      payments,
      attempts as unknown as Repository<PaymentAttempt>,
      refunds as unknown as Repository<Refund>,
      events as unknown as EventPublisher,
    );

    const consumer = new DeliveryEventsConsumer(
      payments,
      manager as unknown as EventWorkerManager,
      service,
    );
    consumer.onModuleInit();

    const delivered = { deliveryId: 77, orderId: 10, riderId: 9 };
    await manager.handler!(delivered, { eventType: EventType.DeliveryDelivered });
    // Duplicate / redelivered event must be harmless (idempotent capture).
    await manager.handler!(delivered, { eventType: EventType.DeliveryDelivered });

    expect(payment.status).toBe(PaymentStatus.Paid);
    expect(payment.paidAt).toBeInstanceOf(Date);
    expect(events.publishEvent).toHaveBeenCalledTimes(1);
    expect(events.publishEvent).toHaveBeenCalledWith(
      QueueName.PaymentEvents,
      EventType.PaymentPaid,
      expect.objectContaining({
        paymentId: 1,
        orderId: 10,
        amount: '200.00',
        method: PaymentMethod.Cod,
        status: PaymentStatus.Paid,
      }),
      expect.any(String),
    );
  });

  it('skips non-existent or non-COD payments', async () => {
    const manager = createManagerFake();
    const events = { publishEvent: jest.fn(async () => undefined) };

    const payments = {
      findOne: jest.fn(async () => null),
    } as unknown as Repository<Payment>;
    const attempts = {
      create: jest.fn((row: Partial<PaymentAttempt>) => row as PaymentAttempt),
      save: jest.fn(async (row: PaymentAttempt) => row),
    };
    const refunds = {
      create: jest.fn((row: Partial<Refund>) => row as Refund),
      save: jest.fn(async (row: Refund) => row),
    };
    const service = new PaymentService(
      payments,
      attempts as unknown as Repository<PaymentAttempt>,
      refunds as unknown as Repository<Refund>,
      events as unknown as EventPublisher,
    );

    const consumer = new DeliveryEventsConsumer(
      payments,
      manager as unknown as EventWorkerManager,
      service,
    );
    consumer.onModuleInit();

    await manager.handler!({ deliveryId: 77, orderId: 10, riderId: 9 }, {
      eventType: EventType.DeliveryDelivered,
    });

    expect(payments.findOne).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ method: PaymentMethod.Cod }) }),
    );
    expect(events.publishEvent).not.toHaveBeenCalled();
  });
});