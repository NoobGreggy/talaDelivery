import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * Payment capture/attempt trail (Phase 10 "payment_attempts"). Records every
 * capture attempt (delivery.delivered, webhook, internal) against a payment so
 * duplicate deliveries/webhooks are auditable.
 */
@Entity('payment_attempts')
@Index(['paymentId'])
export class PaymentAttempt {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'payment_id', type: 'int' })
  paymentId: number;

  /** Origin of the capture: delivery | webhook | internal. */
  @Column({ name: 'source', type: 'varchar', length: 20 })
  source: string;

  /** PAID | FAILED (result of the attempt). */
  @Column({ name: 'status', type: 'varchar', length: 20 })
  status: string;

  @Column({ name: 'attempted_at', type: 'timestamptz' })
  attemptedAt: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}