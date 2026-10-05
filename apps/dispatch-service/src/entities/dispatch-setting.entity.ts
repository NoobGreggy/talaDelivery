import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import {
  CommissionType,
  DistanceMethod,
  EarningsWeekType,
} from '@taladelivery/contracts';

/**
 * Single-row dispatch settings (mirrors Laravel platform_settings, keyed
 * `platform`). Controls rider commission, earnings periods and distance method.
 */
@Entity('dispatch_settings')
export class DispatchSetting {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 64, unique: true, default: 'platform' })
  key: string;

  @Column({ name: 'rider_commission_type', type: 'varchar', length: 20, default: CommissionType.Percentage })
  riderCommissionType: string;

  @Column({ name: 'rider_commission_value', type: 'decimal', precision: 10, scale: 2, default: 0 })
  riderCommissionValue: string;

  @Column({ name: 'earnings_week_type', type: 'varchar', length: 20, default: EarningsWeekType.RollingSevenDays })
  earningsWeekType: string;

  @Column({ name: 'week_starts_on', type: 'int', default: 1 })
  weekStartsOn: number;

  @Column({ name: 'settlement_timezone', type: 'varchar', length: 64, default: 'Asia/Manila' })
  settlementTimezone: string;

  @Column({ name: 'settlement_day_starts_at', type: 'varchar', length: 5, default: '00:00' })
  settlementDayStartsAt: string;

  @Column({ name: 'distance_method', type: 'varchar', length: 20, default: DistanceMethod.StraightLine })
  distanceMethod: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}