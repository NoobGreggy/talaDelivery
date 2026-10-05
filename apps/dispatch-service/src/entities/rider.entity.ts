import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { RiderStatus, VehicleType } from '@taladelivery/contracts';

/**
 * Rider profile owned by the dispatch database. `user_id` references the
 * identity service (no cross-DB FK).
 */
@Entity('riders')
@Index(['status', 'isOnline'])
export class Rider {
  @Column({ name: 'tala_coins_balance', type: 'decimal', precision: 12, scale: 2, default: 0 })
  talaCoinsBalance: string;

  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ name: 'user_id', type: 'int' })
  userId: number;

  @Column({ name: 'vehicle_type', type: 'varchar', length: 20, default: VehicleType.Motorcycle })
  vehicleType: string;

  @Column({ name: 'vehicle_plate', type: 'varchar', length: 20, nullable: true })
  vehiclePlate: string | null;

  @Column({ name: 'license_number', type: 'varchar', length: 50, nullable: true })
  licenseNumber: string | null;

  @Column({ name: 'requirements', type: 'jsonb', nullable: true })
  requirements: Record<string, unknown> | null;

  @Column({ name: 'is_online', type: 'boolean', default: false })
  isOnline: boolean;

  @Column({ name: 'status', type: 'varchar', length: 20, default: RiderStatus.Pending })
  status: string;

  @Column({ name: 'current_latitude', type: 'decimal', precision: 10, scale: 7, nullable: true })
  currentLatitude: string | null;

  @Column({ name: 'current_longitude', type: 'decimal', precision: 10, scale: 7, nullable: true })
  currentLongitude: string | null;

  @Column({ name: 'current_location_accuracy', type: 'decimal', precision: 10, scale: 3, nullable: true })
  currentLocationAccuracy: string | null;

  @Column({ name: 'current_location_heading', type: 'decimal', precision: 8, scale: 3, nullable: true })
  currentLocationHeading: string | null;

  @Column({ name: 'current_location_speed', type: 'decimal', precision: 8, scale: 3, nullable: true })
  currentLocationSpeed: string | null;

  @Column({ name: 'current_location_updated_at', type: 'timestamptz', nullable: true })
  currentLocationUpdatedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
