import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * Refund record (Phase 10 "refunds"). Created when an admin refunds a PAID
 * payment; `amount` stays a decimal string in integer minor units internally.
 */
@Entity('refunds')
@Index(['paymentId'])
export class Refund {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'payment_id', type: 'int' })
  paymentId: number;

  @Column({ name: 'order_id', type: 'int' })
  orderId: number;

  @Column({ name: 'amount', type: 'decimal', precision: 10, scale: 2 })
  amount: string;

  @Column({ name: 'reason', type: 'text', nullable: true })
  reason: string | null;

  @Column({ name: 'refunded_by', type: 'int', nullable: true })
  refundedBy: number | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}