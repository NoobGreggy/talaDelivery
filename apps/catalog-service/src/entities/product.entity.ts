import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

@Entity('products')
@Index(['storeId'])
@Index(['categoryId'])
export class Product {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'store_id', type: 'int' }) storeId: number;
  @Column({ name: 'category_id', type: 'int', nullable: true }) categoryId: number | null;
  @Column({ type: 'varchar', length: 200 }) name: string;
  @Column({ type: 'text', nullable: true }) description: string | null;
  @Column({ type: 'varchar', length: 120, nullable: true }) sku: string | null;
  @Column({ type: 'text', nullable: true }) image: string | null;
  @Column({ type: 'decimal', precision: 12, scale: 2 }) price: string;
  @Column({ type: 'int', default: 0 }) stock: number;
  @Column({ name: 'is_available', type: 'boolean', default: true }) isAvailable: boolean;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' }) updatedAt: Date;
}
