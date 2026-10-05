import { ConflictError, DomainError } from '@taladelivery/common';
import {
  PaymentMethod,
  PaymentStatus,
} from '@taladelivery/contracts';
import {
  EventType,
  EventPublisher,
  QueueName,
} from '@taladelivery/events';
import { Repository } from 'typeorm';
import { Payment } from '../entities/payment.entity';
import { PaymentAttempt } from '../entities/payment-attempt.entity';
import { Refund } from '../entities/refund.entity';
import {
  OrderCreatedPayload,
  PaymentService,
} from './payment.service';

interface Harness {
  service: PaymentService;
  events: { publishEvent: jest.Mock };
  payments: {
    findOne: jest.Mock;
    find: jest.Mock;
    findAndCount: jest.Mock;
    count: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  attempts: { create: jest.Mock; save: jest.Mock };
  refunds: { create: jest.Mock; save: jest.Mock };
}

function createHarness(initialOrderPayments: Map<number, Payment> = new Map()): Harness {
  const events = { publishEvent: jest.fn(async () => undefined) };

  const payments = {
    findOne: jest.fn(async ({ where }: { where: { orderId?: number; id?: number } }) => {
      if (where.id !== undefined) {
        for (const payment of initialOrderPayments.values()) {
          if (payment.id === where.id) return payment;
        }
        return null;
      }
      return initialOrderPayments.get(where.orderId ?? -1) ?? null;
    }),
    find: jest.fn(async () => []),
    findAndCount: jest.fn(async () => [[], 0]),
    count: jest.fn(async () => 0),
    create: jest.fn((row: Partial<Payment>) => row as Payment),
    save: jest.fn(async (payment: Payment) => {
      // TypeORM assigns the primary key on INSERT; ids never come from clients.
      if (payment.id === undefined) {
        (payment as Payment).id = 1;
      }
      return payment;
    }),
  };
  const attempts = {
    create: jest.fn((row: Partial<PaymentAttempt>) => row as PaymentAttempt),
    save: jest.fn(async (row: PaymentAttempt) => row),
  };
  const refunds = {
    create: jest.fn((row: Partial<Refund>) => row as Refund),
    save: jest.fn(async (row: Refund) => row),
  };

  const service = new PaymentService(
    payments as unknown as Repository<Payment>,
    attempts as unknown as Repository<PaymentAttempt>,
    refunds as unknown as Repository<Refund>,
    events as unknown as EventPublisher,
  );

  return { service, events, payments, attempts, refunds };
}

function makePayment(overrides: Partial<Payment> = {}): Payment {
  return {
    id: 1,
    orderId: 10,
    userId: 5,
    method: PaymentMethod.Cod,
    status: PaymentStatus.Pending,
    amount: '200.00',
    paidAt: null,
    failedAt: null,
    refundedAt: null,
    createdAt: new Date('2026-09-29T01:00:00.000Z'),
    updatedAt: new Date('2026-09-29T01:00:00.000Z'),
    ...overrides,
  } as Payment;
}

const createdPayload: OrderCreatedPayload = {
  orderId: 10,
  orderNumber: 'TLD-20260929-ABC123',
  customerId: 5,
  storeId: 3,
  deliveryId: 77,
  status: 'PENDING',
  total: '200.00',
};

describe('PaymentService.ensureForOrder', () => {
  it('creates a PENDING COD payment from order.created and publishes payment.created', async () => {
    const h = createHarness();

    const payment = await h.service.ensureForOrder(createdPayload);

    expect(payment.orderId).toBe(10);
    expect(payment.method).toBe(PaymentMethod.Cod);
    expect(payment.status).toBe(PaymentStatus.Pending);
    expect(payment.amount).toBe('200.00');
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.PaymentEvents,
      EventType.PaymentCreated,
      expect.objectContaining({
        paymentId: 1,
        orderId: 10,
        amount: '200.00',
        method: PaymentMethod.Cod,
        status: PaymentStatus.Pending,
      }),
      expect.any(String),
    );
  });

  it('is idempotent: a redelivered order.created returns the existing row', async () => {
    const existing = makePayment();
    const h = createHarness(new Map([[10, existing]]));

    const payment = await h.service.ensureForOrder(createdPayload);

    expect(payment).toBe(existing);
    expect(h.payments.save).not.toHaveBeenCalled();
    expect(h.events.publishEvent).not.toHaveBeenCalled();
  });
});

describe('PaymentService.capture', () => {
  it('captures a PENDING COD payment -> PAID and publishes payment.paid', async () => {
    const h = createHarness();
    const payment = makePayment();

    const result = await h.service.capture(payment, 'delivery');

    expect(result.status).toBe(PaymentStatus.Paid);
    expect(result.paidAt).toBeInstanceOf(Date);
    expect(h.attempts.save).toHaveBeenCalledWith(
      expect.objectContaining({
        paymentId: 1,
        source: 'delivery',
        status: PaymentStatus.Paid,
      }),
    );
    expect(h.events.publishEvent).toHaveBeenCalledWith(
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

  it('is idempotent: capturing an already-PAID payment is a no-op (single event)', async () => {
    const h = createHarness();
    const payment = makePayment({ status: PaymentStatus.Paid });

    const result = await h.service.capture(payment, 'delivery');

    expect(result.status).toBe(PaymentStatus.Paid);
    expect(h.payments.save).not.toHaveBeenCalled();
    expect(h.events.publishEvent).not.toHaveBeenCalled();
  });

  it('rejects capturing a refunded payment', async () => {
    const h = createHarness();
    const payment = makePayment({ status: PaymentStatus.Refunded });

    await expect(h.service.capture(payment, 'delivery')).rejects.toThrow(
      'Payment cannot be captured in its current state.',
    );
    expect(h.events.publishEvent).not.toHaveBeenCalled();
  });
});

describe('PaymentService.adminTotals / collectedToday', () => {
  it('returns the count and the sum of today\'s PAID payments as a decimal string', async () => {
    const h = createHarness();
    h.payments.count.mockResolvedValue(3);
    h.payments.find.mockResolvedValue([
      { amount: '100.50' },
      { amount: '49.00' },
    ] as Payment[]);

    const totals = await h.service.adminTotals();

    expect(totals).toEqual({ payments: 3, collectedToday: '149.50' });
    expect(h.payments.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: PaymentStatus.Paid }),
      }),
    );
  });

  it('keeps money in integer minor units (no float drift)', async () => {
    const h = createHarness();
    h.payments.find.mockResolvedValue([
      { amount: '0.10' },
      { amount: '0.20' },
      { amount: '0.70' },
    ] as Payment[]);

    expect(await h.service.collectedBetween(new Date(), new Date())).toBe('1.00');
  });
});

describe('PaymentService.refund', () => {
  it('refunds a PAID payment, records the refund and publishes payment.refunded', async () => {
    const h = createHarness();
    const payment = makePayment({ status: PaymentStatus.Paid, paidAt: new Date() });

    const result = await h.service.refund(payment, 'Customer request', 9);

    expect(result.status).toBe(PaymentStatus.Refunded);
    expect(result.refundedAt).toBeInstanceOf(Date);
    expect(h.refunds.save).toHaveBeenCalledWith(
      expect.objectContaining({
        paymentId: 1,
        orderId: 10,
        amount: '200.00',
        reason: 'Customer request',
        refundedBy: 9,
      }),
    );
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.PaymentEvents,
      EventType.PaymentRefunded,
      expect.objectContaining({ status: PaymentStatus.Refunded }),
      expect.any(String),
    );
  });

  it('refuses to refund a payment that is not yet PAID', async () => {
    const h = createHarness();
    const payment = makePayment();

    await expect(h.service.refund(payment)).rejects.toThrow(DomainError);
    await expect(h.service.refund(payment)).rejects.toThrow(
      'Payment must be completed before it can be refunded.',
    );
  });

  it('refuses to refund twice', async () => {
    const h = createHarness();
    const payment = makePayment({ status: PaymentStatus.Refunded });

    await expect(h.service.refund(payment)).rejects.toThrow(ConflictError);
    await expect(h.service.refund(payment)).rejects.toThrow(
      'This payment has already been refunded.',
    );
  });
});

describe('PaymentService.fail', () => {
  it('fails a PENDING payment and publishes payment.failed', async () => {
    const h = createHarness();
    const payment = makePayment();

    const result = await h.service.fail(payment, 'webhook');

    expect(result.status).toBe(PaymentStatus.Failed);
    expect(result.failedAt).toBeInstanceOf(Date);
    expect(h.events.publishEvent).toHaveBeenCalledWith(
      QueueName.PaymentEvents,
      EventType.PaymentFailed,
      expect.objectContaining({ status: PaymentStatus.Failed }),
      expect.any(String),
    );
  });

  it('is idempotent for an already-FAILED payment', async () => {
    const h = createHarness();
    const payment = makePayment({ status: PaymentStatus.Failed });

    await h.service.fail(payment);

    expect(h.events.publishEvent).not.toHaveBeenCalled();
  });
});