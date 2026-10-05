import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';
@Entity('customer_addresses')
@Index(['userId'])
export class CustomerAddress {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'user_id', type: 'int' }) userId: number;
  @Column({ type: 'varchar', length: 80, nullable: true }) label: string | null;
  @Column({ type: 'varchar', length: 160 }) recipient_name: string;
  @Column({ type: 'varchar', length: 40 }) phone: string;
  @Column({ type: 'text' }) address_line: string;
  @Column({ type: 'varchar', length: 120, nullable: true }) barangay: string | null;
  @Column({ type: 'varchar', length: 120 }) city: string;
  @Column({ type: 'varchar', length: 120 }) province: string;
  @Column({ type: 'varchar', length: 20, nullable: true }) postal_code: string | null;
  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true }) latitude: string | null;
  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true }) longitude: string | null;
  @Column({ type: 'text', nullable: true }) notes: string | null;
  @Column({ type: 'boolean', default: false }) is_default: boolean;
}
