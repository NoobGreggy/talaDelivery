import { Column, CreateDateColumn, Entity, Index, JoinTable, ManyToMany, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { StoreCategory } from './store-category.entity';
import { StoreStatus } from '@taladelivery/contracts';

export interface OpeningHoursDay {
  open: string;
  close: string;
  isClosed: boolean;
}

export type OpeningHours = Record<string, OpeningHoursDay>;

export const DEFAULT_OPENING_HOURS: OpeningHours = {
  monday: { open: '09:00', close: '17:00', isClosed: false },
  tuesday: { open: '09:00', close: '17:00', isClosed: false },
  wednesday: { open: '09:00', close: '17:00', isClosed: false },
  thursday: { open: '09:00', close: '17:00', isClosed: false },
  friday: { open: '09:00', close: '17:00', isClosed: false },
  saturday: { open: '09:00', close: '17:00', isClosed: false },
  sunday: { open: '09:00', close: '17:00', isClosed: false },
};

/** Store data is owned exclusively by merchant-service. */
@Entity('stores')
@Index(['status'])
export class Store {
  // Zone IDs belong to dispatch-service; no cross-database foreign key.
  @Column({ name: 'delivery_zone_ids', type: 'int', array: true, default: '{}' }) deliveryZoneIds: number[];
  @ManyToMany(() => StoreCategory, (category) => category.stores, { eager: true })
  @JoinTable({ name: 'store_category_tags', joinColumn: { name: 'store_id' }, inverseJoinColumn: { name: 'category_id' } })
  categories: StoreCategory[];
  @PrimaryGeneratedColumn() id: number;
  @Column({ type: 'varchar', length: 160 }) name: string;
  @Column({ type: 'text', nullable: true }) description: string | null;
  @Column({ type: 'varchar', length: 254, nullable: true }) email: string | null;
  @Column({ type: 'varchar', length: 180, unique: true }) slug: string;
  @Column({ type: 'varchar', length: 20, default: StoreStatus.Active }) status: string;
  @Column({ type: 'text', nullable: true }) address: string | null;
  @Column({ type: 'varchar', length: 40, nullable: true }) phone: string | null;
  @Column({ name: 'latitude', type: 'decimal', precision: 10, scale: 7, nullable: true }) latitude: string | null;
  @Column({ name: 'longitude', type: 'decimal', precision: 10, scale: 7, nullable: true }) longitude: string | null;
  @Column({ name: 'opening_hours', type: 'jsonb', nullable: true }) openingHours: OpeningHours | null;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' }) updatedAt: Date;
}
