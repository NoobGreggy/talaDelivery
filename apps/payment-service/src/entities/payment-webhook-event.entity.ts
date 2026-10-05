import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * Webhook-ready design (Phase 10 "payment_webhook_events"): raw provider
 * callbacks are stored durably before processing so duplicates are detectable
 * and the audit trail is complete. No public webhook endpoint exists yet (the
 * MVP is COD captured on delivery); providers will POST here once wired.
 */
@Entity('payment_webhook_events')
@Index(['provider', 'eventId'])
export class PaymentWebhookEvent {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'provider', type: 'varchar', length: 30 })
  provider: string;

  @Column({ name: 'event_id', type: 'varchar', length: 128, nullable: true })
  eventId: string | null;

  @Column({ name: 'payload', type: 'jsonb', nullable: true })
  payload: Record<string, unknown> | null;

  @Column({ name: 'received_at', type: 'timestamptz' })
  receivedAt: Date;

  @Column({ name: 'processed_at', type: 'timestamptz', nullable: true })
  processedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}