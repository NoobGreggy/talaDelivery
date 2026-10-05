import { Injectable } from '@nestjs/common';
import { Payment } from '../entities/payment.entity';
import { moneyString, toIso } from '../common/format.util';

/** Laravel-shaped API resource for a payment (snake_case, decimals as strings). */
export interface PaymentResourceJson {
  id: number;
  order_id: number;
  user_id: number | null;
  method: string;
  status: string;
  amount: string;
  is_paid: boolean;
  paid_at: string | null;
  failed_at: string | null;
  refunded_at: string | null;
  created_at: string;
  updated_at: string;
}

/** Internal cross-service snapshot (camelCase, decimal strings). */
export interface PaymentSnapshot {
  id: number;
  orderId: number;
  userId: number | null;
  method: string;
  status: string;
  amount: string;
  paidAt: string | null;
  failedAt: string | null;
  refundedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class PaymentResourcesService {
  toJson(payment: Payment): PaymentResourceJson {
    return {
      id: payment.id,
      order_id: payment.orderId,
      user_id: payment.userId,
      method: payment.method,
      status: payment.status,
      amount: moneyString(payment.amount),
      is_paid: payment.status === 'PAID',
      paid_at: toIso(payment.paidAt),
      failed_at: toIso(payment.failedAt),
      refunded_at: toIso(payment.refundedAt),
      created_at: toIso(payment.createdAt) ?? new Date().toISOString(),
      updated_at: toIso(payment.updatedAt) ?? new Date().toISOString(),
    };
  }

  toSnapshot(payment: Payment): PaymentSnapshot {
    return {
      id: payment.id,
      orderId: payment.orderId,
      userId: payment.userId,
      method: payment.method,
      status: payment.status,
      amount: moneyString(payment.amount),
      paidAt: toIso(payment.paidAt),
      failedAt: toIso(payment.failedAt),
      refundedAt: toIso(payment.refundedAt),
      createdAt: toIso(payment.createdAt) ?? new Date().toISOString(),
      updatedAt: toIso(payment.updatedAt) ?? new Date().toISOString(),
    };
  }
}