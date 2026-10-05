import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DeliveryStatus } from '@taladelivery/contracts';

/**
 * Delivery row owned by dispatch. `order_id` and `store_id` are projections
 * referencing order/merchant services (no cross-DB FKs). `rider_id` points at
 * the dispatch riders table.
 */
@Entity('deliveries')
@Index(['storeId', 'status'])
@Index(['riderId', 'status'])
@Index(['orderId'])
export class Delivery {
  @Column({ name: 'delivery_zone_id', type: 'int', nullable: true })
  deliveryZoneId: number | null;

  @Column({ name: 'tala_coins_percent', type: 'decimal', precision: 5, scale: 2, default: 0 })
  talaCoinsPercent: string;

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'order_id', type: 'int' })
  orderId: number;

  @Column({ name: 'store_id', type: 'int' })
  storeId: number;

  @Column({ name: 'rider_id', type: 'int', nullable: true })
  riderId: number | null;

  @Column({ name: 'status', type: 'varchar', length: 20, default: DeliveryStatus.Unassigned })
  status: string;

  @Column({ name: 'pickup_address', type: 'text', nullable: true })
  pickupAddress: string | null;

  @Column({ name: 'pickup_latitude', type: 'decimal', precision: 10, scale: 7, nullable: true })
  pickupLatitude: string | null;

  @Column({ name: 'pickup_longitude', type: 'decimal', precision: 10, scale: 7, nullable: true })
  pickupLongitude: string | null;

  @Column({ name: 'delivery_address', type: 'text', nullable: true })
  deliveryAddress: string | null;

  @Column({ name: 'delivery_latitude', type: 'decimal', precision: 10, scale: 7, nullable: true })
  deliveryLatitude: string | null;

  @Column({ name: 'delivery_longitude', type: 'decimal', precision: 10, scale: 7, nullable: true })
  deliveryLongitude: string | null;

  @Column({ name: 'distance_km', type: 'decimal', precision: 8, scale: 2, nullable: true })
  distanceKm: string | null;

  @Column({ name: 'delivery_fee', type: 'decimal', precision: 10, scale: 2, nullable: true })
  deliveryFee: string | null;

  @Column({ name: 'rider_commission', type: 'decimal', precision: 10, scale: 2, nullable: true })
  riderCommission: string | null;

  @Column({ name: 'commission_type', type: 'varchar', length: 20, nullable: true })
  commissionType: string | null;

  @Column({ name: 'commission_value', type: 'decimal', precision: 10, scale: 2, nullable: true })
  commissionValue: string | null;

  @Column({ name: 'cancelled_by', type: 'varchar', length: 20, nullable: true })
  cancelledBy: string | null;

  @Column({ name: 'cancellation_reason', type: 'text', nullable: true })
  cancellationReason: string | null;

  @Column({ name: 'assigned_at', type: 'timestamptz', nullable: true })
  assignedAt: Date | null;

  @Column({ name: 'accepted_at', type: 'timestamptz', nullable: true })
  acceptedAt: Date | null;

  @Column({ name: 'picked_up_at', type: 'timestamptz', nullable: true })
  pickedUpAt: Date | null;

  @Column({ name: 'started_at', type: 'timestamptz', nullable: true })
  startedAt: Date | null;

  @Column({ name: 'delivered_at', type: 'timestamptz', nullable: true })
  deliveredAt: Date | null;

  @Column({ name: 'cancelled_at', type: 'timestamptz', nullable: true })
  cancelledAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
