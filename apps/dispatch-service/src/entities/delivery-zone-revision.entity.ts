import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export type ZoneRevisionAction = 'CREATED' | 'UPDATED' | 'ARCHIVED';

/** Audit trail row for delivery zone changes (mirrors delivery_zone_revisions). */
@Entity('delivery_zone_revisions')
@Index(['deliveryZoneId', 'createdAt'])
export class DeliveryZoneRevision {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'delivery_zone_id', type: 'int' })
  deliveryZoneId: number;

  @Column({ name: 'user_id', type: 'int', nullable: true })
  userId: number | null;

  @Column({ type: 'varchar', length: 20 })
  action: string;

  @Column({ type: 'jsonb', nullable: true })
  before: Record<string, unknown> | null;

  @Column({ type: 'jsonb', nullable: true })
  after: Record<string, unknown> | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}