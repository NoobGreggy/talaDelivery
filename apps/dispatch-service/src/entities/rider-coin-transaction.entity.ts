import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('rider_coin_transactions')
@Index(['riderId', 'id'])
export class RiderCoinTransaction {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'rider_id', type: 'int' }) riderId: number;
  @Index({ unique: true })
  @Column({ name: 'delivery_id', type: 'int', nullable: true }) deliveryId: number | null;
  @Index({ unique: true })
  @Column({ name: 'request_id', type: 'uuid', nullable: true }) requestId: string | null;
  @Column({ type: 'varchar', length: 20 }) type: 'TOP_UP' | 'DELIVERY_DEDUCTION';
  @Column({ type: 'decimal', precision: 12, scale: 2 }) amount: string;
  @Column({ name: 'balance_after', type: 'decimal', precision: 12, scale: 2 }) balanceAfter: string;
  @Column({ name: 'deduction_percent', type: 'decimal', precision: 5, scale: 2, nullable: true }) deductionPercent: string | null;
  @Column({ name: 'delivery_zone_id', type: 'int', nullable: true }) deliveryZoneId: number | null;
  @Column({ name: 'actor_id', type: 'int', nullable: true }) actorId: number | null;
  @Column({ type: 'varchar', length: 500, nullable: true }) note: string | null;
  // Saved with the deduction so an unavailable queue cannot lose the admin alert.
  @Index()
  @Column({ name: 'admin_alert_pending', type: 'boolean', default: false }) adminAlertPending: boolean;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
}
