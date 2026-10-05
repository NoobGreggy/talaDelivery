import { Column, CreateDateColumn, Entity, ManyToMany, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { Store } from './store.entity';

@Entity('store_categories')
export class StoreCategory {
  @Column({ type: 'varchar', length: 60, default: 'restaurant_rounded' }) icon: string;
  @PrimaryGeneratedColumn() id: number;
  @Column({ type: 'varchar', length: 80 }) name: string;
  @Column({ name: 'normalized_name', type: 'varchar', length: 80, unique: true }) normalizedName: string;
  @Column({ type: 'varchar', length: 500, nullable: true }) description: string | null;
  @Column({ name: 'is_active', type: 'boolean', default: true }) isActive: boolean;
  @ManyToMany(() => Store, (store) => store.categories) stores: Store[];
  storeCount?: number;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' }) updatedAt: Date;
}
