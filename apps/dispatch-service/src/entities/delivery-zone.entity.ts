import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DeliveryZoneStatus } from '@taladelivery/contracts';

export interface PolygonAddress {
  [index: number]: number;
}

export type GeoJsonBoundary =
  | { type: 'Polygon'; coordinates: number[][][] }
  | { type: 'MultiPolygon'; coordinates: number[][][][] };

/**
 * Delivery zone configuring pricing + coverage for a city/province.
 * `created_by` / `updated_by` reference identity users (no cross-DB FK).
 */
@Entity('delivery_zones')
@Index(['status', 'effectiveFrom'])
@Index(['city', 'province'])
export class DeliveryZone {
  @Column({ name: 'tala_coins_percent', type: 'decimal', precision: 5, scale: 2, default: 0 })
  talaCoinsPercent: string;

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  city: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  province: string | null;

  @Column({ name: 'boundary_geojson', type: 'jsonb', nullable: true })
  boundaryGeoJson: GeoJsonBoundary | null;

  @Column({ name: 'base_fee', type: 'decimal', precision: 10, scale: 2, default: 49 })
  baseFee: string;

  @Column({ name: 'included_km', type: 'decimal', precision: 8, scale: 2, default: 5 })
  includedKm: string;

  @Column({ name: 'maximum_delivery_km', type: 'decimal', precision: 8, scale: 2, nullable: true })
  maximumDeliveryKm: string | null;

  @Column({ name: 'extra_fee_per_km', type: 'decimal', precision: 10, scale: 2, default: 10 })
  extraFeePerKm: string;

  @Column({ name: 'maximum_delivery_fee', type: 'decimal', precision: 10, scale: 2, nullable: true })
  maximumDeliveryFee: string | null;

  @Column({ name: 'distance_rounding_km', type: 'decimal', precision: 5, scale: 2, default: 0.1 })
  distanceRoundingKm: string;

  @Column({ name: 'effective_from', type: 'timestamptz', nullable: true })
  effectiveFrom: Date | null;

  @Column({ name: 'status', type: 'varchar', length: 20, default: DeliveryZoneStatus.Draft })
  status: string;

  @Column({ name: 'created_by', type: 'int', nullable: true })
  createdBy: number | null;

  @Column({ name: 'updated_by', type: 'int', nullable: true })
  updatedBy: number | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
