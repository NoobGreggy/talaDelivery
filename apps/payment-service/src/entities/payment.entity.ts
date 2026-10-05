import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { PaymentMethod, PaymentStatus } from '@taladelivery/contracts';

/**
 * Payment row owned by payment-service (the authoritative source for payment
 * state). `order_id`/`user_id` reference order/identity services (no cross-DB
 * FKs). `amount` is a decimal string; every money computation uses integer
 * minor units.
 */
@Entity('payments')
@Index(['orderId'])
@Index(['userId', 'status'])
@Index(['status', 'paidAt'])
export class Payment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'order_id', type: 'int' })
  orderId: number;

  @Column({ name: 'user_id', type: 'int', nullable: true })
  userId: number | null;

  @Column({ name: 'method', type: 'varchar', length: 20, default: PaymentMethod.Cod })
  method: string;

  @Column({ name: 'status', type: 'varchar', length: 20, default: PaymentStatus.Pending })
  status: string;

  @Column({ name: 'amount', type: 'decimal', precision: 10, scale: 2 })
  amount: string;

  @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
  paidAt: Date | null;

  @Column({ name: 'failed_at', type: 'timestamptz', nullable: true })
  failedAt: Date | null;

  @Column({ name: 'refunded_at', type: 'timestamptz', nullable: true })
  refundedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}