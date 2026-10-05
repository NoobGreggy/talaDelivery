import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import {
  ConflictError,
  DomainError,
  fromMinor,
  requestContext,
  toMinor,
} from '@taladelivery/common';
import {
  PaymentMethod,
  PaymentStatus,
} from '@taladelivery/contracts';
import {
  EventPublisher,
  EventType,
  QueueName,
} from '@taladelivery/events';
import { Payment } from '../entities/payment.entity';
import { PaymentAttempt } from '../entities/payment-attempt.entity';
import { Refund } from '../entities/refund.entity';
import { moneyString } from '../common/format.util';

export interface OrderCreatedPayload {
  orderId: number;
  orderNumber: string;
  customerId: number;
  storeId: number;
  deliveryId: number | null;
  status: string;
  total: string;
}

export interface PaymentStatusPayload {
  paymentId: number;
  orderId: number;
  amount: string;
  method: string;
  status: string;
}

export type PaymentCaptureSource = 'delivery' | 'webhook' | 'internal';

/**
 * Payment state machine (authoritative payment-service owner):
 *
 *   PENDING --(capture)--> PAID --(refund)--> REFUNDED
 *   PENDING --(fail)-----> FAILED
 *
 * COD payments are created from `order.created` (PENDING) and captured on
 * `delivery.delivered`. Every transition publishes a `payment-events` event
 * consumed by order (projection), notification and realtime.
 *
 * Consumers are idempotent: capturing/ failing an already-final payment is a
 * no-op, so redelivered events never emit duplicate events or rows.
 */
@Injectable()
export class PaymentService {
  constructor(
    @InjectRepository(Payment) private readonly payments: Repository<Payment>,
    @InjectRepository(PaymentAttempt)
    private readonly attempts: Repository<PaymentAttempt>,
    @InjectRepository(Refund) private readonly refunds: Repository<Refund>,
    private readonly events: EventPublisher,
  ) {}

  /** Lazy/idempotent COD payment creation for a new order (order.created). */
  async ensureForOrder(payload: OrderCreatedPayload): Promise<Payment> {
    const existing = await this.payments.findOne({
      where: { orderId: payload.orderId },
    });
    if (existing !== null) {
      return existing;
    }
    const saved = await this.payments.save(
      this.payments.create({
        orderId: payload.orderId,
        userId: payload.customerId,
        method: PaymentMethod.Cod,
        status: PaymentStatus.Pending,
        amount: moneyString(payload.total),
        paidAt: null,
        failedAt: null,
        refundedAt: null,
      }),
    );
    await this.publishStatus(saved, EventType.PaymentCreated);
    return saved;
  }

  /** Capture a PENDING payment -> PAID (COD capture on delivery, webhooks). */
  async capture(payment: Payment, source: PaymentCaptureSource = 'internal'): Promise<Payment> {
    if (payment.status === PaymentStatus.Paid) {
      // Idempotent: a redelivered delivery.delivered must not double-capture.
      return payment;
    }
    if (
      payment.status === PaymentStatus.Failed ||
      payment.status === PaymentStatus.Refunded
    ) {
      throw new DomainError(
        'Payment cannot be captured in its current state.',
      );
    }
    payment.status = PaymentStatus.Paid;
    payment.paidAt = new Date();
    const saved = await this.payments.save(payment);
    await this.recordAttempt(saved, source);
    await this.publishStatus(saved, EventType.PaymentPaid);
    return saved;
  }

  /** Fail a PENDING payment (webhook-ready path). */
  async fail(payment: Payment, source: PaymentCaptureSource = 'webhook'): Promise<Payment> {
    if (payment.status === PaymentStatus.Failed) {
      return payment;
    }
    if (payment.status === PaymentStatus.Paid || payment.status === PaymentStatus.Refunded) {
      throw new DomainError('Payment cannot be failed in its current state.');
    }
    payment.status = PaymentStatus.Failed;
    payment.failedAt = new Date();
    const saved = await this.payments.save(payment);
    await this.recordAttempt(saved, source);
    await this.publishStatus(saved, EventType.PaymentFailed);
    return saved;
  }

  /** Refund a PAID payment (admin). */
  async refund(
    payment: Payment,
    reason: string | null = null,
    refundedBy: number | null = null,
  ): Promise<Payment> {
    if (payment.status === PaymentStatus.Refunded) {
      throw new ConflictError('This payment has already been refunded.');
    }
    if (payment.status !== PaymentStatus.Paid) {
      throw new DomainError('Payment must be completed before it can be refunded.');
    }
    payment.status = PaymentStatus.Refunded;
    payment.refundedAt = new Date();
    const saved = await this.payments.save(payment);
    await this.refunds.save(
      this.refunds.create({
        paymentId: saved.id,
        orderId: saved.orderId,
        amount: moneyString(saved.amount),
        reason,
        refundedBy,
      }),
    );
    await this.publishStatus(saved, EventType.PaymentRefunded);
    return saved;
  }

  async byId(id: number): Promise<Payment | null> {
    return this.payments.findOne({ where: { id } });
  }

  async byOrder(orderId: number): Promise<Payment | null> {
    return this.payments.findOne({ where: { orderId } });
  }

  async forUser(
    userId: number,
    page: number,
    perPage: number,
  ): Promise<{ items: Payment[]; total: number }> {
    const [items, total] = await this.payments.findAndCount({
      where: { userId },
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { items, total };
  }

  async all(page: number, perPage: number): Promise<{ items: Payment[]; total: number }> {
    const [items, total] = await this.payments.findAndCount({
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { items, total };
  }

  /**
   * Internal contract `GET /internal/admin/totals`:
   *   { payments, collectedToday }
   * `collectedToday` = sum of today's PAID payments as a decimal string
   * (integer minor-unit math, never floats).
   */
  async adminTotals(): Promise<{ payments: number; collectedToday: string }> {
    const now = new Date();
    const start = startOfLocalDay(now);
    const end = endOfLocalDay(now);
    const [payments, collectedToday] = await Promise.all([
      this.payments.count(),
      this.collectedBetween(start, end),
    ]);
    return { payments, collectedToday };
  }

  /** Sum of PAID payments captured inside [start, end) as a decimal string. */
  async collectedBetween(start: Date, end: Date): Promise<string> {
    const rows = await this.payments.find({
      where: {
        status: PaymentStatus.Paid,
        paidAt: Between(start, end),
      },
      select: { amount: true },
    });
    const totalMinor = rows.reduce((sum, row) => sum + toMinor(row.amount), 0);
    return fromMinor(totalMinor);
  }

  private async recordAttempt(payment: Payment, source: PaymentCaptureSource): Promise<void> {
    await this.attempts.save(
      this.attempts.create({
        paymentId: payment.id,
        source,
        status: payment.status,
        attemptedAt: new Date(),
      }),
    );
  }

  private async publishStatus(payment: Payment, eventType: string): Promise<void> {
    const payload: PaymentStatusPayload = {
      paymentId: payment.id,
      orderId: payment.orderId,
      amount: moneyString(payment.amount),
      method: payment.method,
      status: payment.status,
    };
    await this.events.publishEvent(
      QueueName.PaymentEvents,
      eventType,
      payload,
      requestContext().correlationId,
    );
  }
}

function startOfLocalDay(now: Date): Date {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  return start;
}

function endOfLocalDay(now: Date): Date {
  const end = new Date(now);
  end.setHours(23, 59, 59, 999);
  return end;
}