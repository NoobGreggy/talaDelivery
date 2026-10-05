import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('order_items')
@Index(['orderId'])
export class OrderItem {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'order_id', type: 'int' }) orderId: number;
  @Column({ name: 'product_id', type: 'int' }) productId: number;
  @Column({ type: 'varchar', length: 200 }) productName: string;
  @Column({ type: 'int' }) quantity: number;
  @Column({ type: 'decimal', precision: 12, scale: 2 }) unitPrice: string;
  @Column({ type: 'decimal', precision: 12, scale: 2 }) subtotal: string;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
}
