import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { OrderStatus, PaymentMethod } from '@taladelivery/contracts';

@Entity('orders')
@Index(['customerId'])
@Index(['storeId'])
@Index(['status'])
export class Order {
  @Column({ type: 'text', nullable: true }) notes: string | null;
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'order_number', type: 'varchar', length: 30, unique: true }) orderNumber: string;
  @Column({ name: 'customer_id', type: 'int' }) customerId: number;
  @Column({ name: 'store_id', type: 'int' }) storeId: number;
  @Column({ name: 'delivery_id', type: 'int', nullable: true }) deliveryId: number | null;
  @Column({ type: 'varchar', length: 20, default: OrderStatus.Pending }) status: string;
  @Column({ name: 'payment_method', type: 'varchar', length: 10, default: PaymentMethod.Cod }) paymentMethod: string;
  @Column({ name: 'payment_status', type: 'varchar', length: 20, default: 'PENDING' }) paymentStatus: string;
  @Column({ type: 'decimal', precision: 12, scale: 2 }) subtotal: string;
  @Column({ type: 'decimal', precision: 12, scale: 2, default: '0.00' }) discount: string;
  @Column({ type: 'decimal', precision: 12, scale: 2, default: '0.00' }) deliveryFee: string;
  @Column({ type: 'decimal', precision: 12, scale: 2 }) total: string;
  @Column({ name: 'pickup_address', type: 'text', nullable: true }) pickupAddress: string | null;
  @Column({ name: 'pickup_latitude', type: 'varchar', length: 20, nullable: true }) pickupLatitude: string | null;
  @Column({ name: 'pickup_longitude', type: 'varchar', length: 20, nullable: true }) pickupLongitude: string | null;
  @Column({ name: 'delivery_address', type: 'text', nullable: true }) deliveryAddress: string | null;
  @Column({ name: 'delivery_latitude', type: 'varchar', length: 20, nullable: true }) deliveryLatitude: string | null;
  @Column({ name: 'delivery_longitude', type: 'varchar', length: 20, nullable: true }) deliveryLongitude: string | null;
  @Column({ name: 'customer_name', type: 'varchar', length: 160 }) customerName: string;
  @Column({ name: 'customer_phone', type: 'varchar', length: 40, nullable: true }) customerPhone: string | null;
  @Column({ name: 'store_name', type: 'varchar', length: 160 }) storeName: string;
  @Column({ name: 'store_snapshot', type: 'jsonb', nullable: true }) storeSnapshot: Record<string, unknown> | null;
  @Column({ name: 'cancelled_by', type: 'varchar', length: 30, nullable: true }) cancelledBy: string | null;
  @Column({ name: 'cancellation_reason', type: 'text', nullable: true }) cancellationReason: string | null;
  @Column({ name: 'cancelled_at', type: 'timestamptz', nullable: true }) cancelledAt: Date | null;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' }) updatedAt: Date;
}
