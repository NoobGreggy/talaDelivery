import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DeliveryOfferStatus } from '@taladelivery/contracts';

/**
 * A delivery offer sent to a single rider. `rider_id` references dispatch
 * riders.id (Laravel referenced users.id; the split stores the dispatch id and
 * resolves the user through the current JWT).
 */
@Entity('delivery_offers')
@Index(['deliveryId', 'status'])
@Index(['riderId', 'status'])
export class DeliveryOffer {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'delivery_id', type: 'int' })
  deliveryId: number;

  @Column({ name: 'rider_id', type: 'int' })
  riderId: number;

  @Column({ name: 'status', type: 'varchar', length: 20, default: DeliveryOfferStatus.Pending })
  status: string;

  @Column({ name: 'offered_at', type: 'timestamptz', nullable: true })
  offeredAt: Date | null;

  @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
  expiresAt: Date | null;

  @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
  respondedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}