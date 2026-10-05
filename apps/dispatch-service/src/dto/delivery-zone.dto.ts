import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  ValidateIf,
  ValidateNested,
  Matches,
} from 'class-validator';

/** Numeric fields arrive as decimal strings in the API (Laravel decimal casts). */
export const NUMERIC_STRING = /^(0|[1-9]\d*)(\.\d+)?$/;

/**
 * Zone statuses accepted on input. `INACTIVE` is a legacy alias Laravel maps
 * to ARCHIVED before persistence (Store/UpdateDeliveryZoneRequest).
 */
const ZONE_STATUS_INPUT = ['DRAFT', 'ACTIVE', 'SUSPENDED', 'ARCHIVED', 'INACTIVE'] as const;

/**
 * Admin POST admin/delivery-zones (mirrors StoreDeliveryZoneRequest:
 * distance_rounding defaults to 0.1, status INACTIVE -> ARCHIVED, city
 * required only without a boundary).
 */
export class StoreDeliveryZoneDto {
  @ValidateIf((_object, value) => value !== undefined)
  @IsString()
  @Matches(/^(?:100(?:\.0{1,2})?|(?:0|[1-9]\d?)(?:\.\d{1,2})?)$/)
  tala_coins_percent?: string;

  @IsString()
  @MaxLength(255)
  name: string;

  @ValidateIf((o: StoreDeliveryZoneDto) => !o.boundary_geojson)
  @IsOptional()
  @IsString()
  @MaxLength(255)
  city?: string | null;

  @IsString()
  @MaxLength(255)
  province: string;

  @IsOptional()
  @IsObject()
  boundary_geojson?: Record<string, unknown> | null;

  @IsString()
  @Matches(NUMERIC_STRING)
  base_fee: string;

  @IsString()
  @Matches(NUMERIC_STRING)
  included_km: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  maximum_delivery_km?: string | null;

  @IsString()
  @Matches(NUMERIC_STRING)
  extra_fee_per_km: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  maximum_delivery_fee?: string | null;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  distance_rounding_km?: string;

  @IsOptional()
  @IsDateString()
  effective_from?: string | null;

  @IsOptional()
  @IsIn(ZONE_STATUS_INPUT)
  status?: string;
}

/**
 * Admin PUT admin/delivery-zones/:id (mirrors UpdateDeliveryZoneRequest; all
 * fields optional, INACTIVE -> ARCHIVED).
 */
export class UpdateDeliveryZoneDto {
  @ValidateIf((_object, value) => value !== undefined)
  @IsString()
  @Matches(/^(?:100(?:\.0{1,2})?|(?:0|[1-9]\d?)(?:\.\d{1,2})?)$/)
  tala_coins_percent?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  city?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  province?: string;

  @IsOptional()
  @IsObject()
  boundary_geojson?: Record<string, unknown> | null;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  base_fee?: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  included_km?: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  maximum_delivery_km?: string | null;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  extra_fee_per_km?: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  maximum_delivery_fee?: string | null;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  distance_rounding_km?: string;

  @IsOptional()
  @IsDateString()
  effective_from?: string | null;

  @IsOptional()
  @IsIn(ZONE_STATUS_INPUT)
  status?: string;
}

/** Zone pricing rules used by the admin preview endpoint (zone.*). */
export class ZonePricingInputDto {
  @IsOptional()
  @IsObject()
  boundary_geojson?: Record<string, unknown> | null;

  @IsString()
  @Matches(NUMERIC_STRING)
  base_fee: string;

  @IsString()
  @Matches(NUMERIC_STRING)
  included_km: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  maximum_delivery_km?: string | null;

  @IsString()
  @Matches(NUMERIC_STRING)
  extra_fee_per_km: string;

  @IsOptional()
  @IsString()
  @Matches(NUMERIC_STRING)
  maximum_delivery_fee?: string | null;

  @IsString()
  @Matches(NUMERIC_STRING)
  distance_rounding_km: string;
}

/**
 * Admin POST admin/delivery-zones/preview (mirrors
 * PreviewDeliveryZonePricingRequest).
 */
export class PreviewZonePricingDto {
  /**
   * `@Type` alone is NOT enough: the global pipe runs with `whitelist: true`,
   * which strips any property that carries no validation decorator, so `zone`
   * arrived as `undefined` and every preview call died with a 500.
   * `@ValidateNested()` both registers the property and validates the child.
   */
  @IsObject()
  @ValidateNested()
  @Type(() => ZonePricingInputDto)
  zone: ZonePricingInputDto;

  @IsString()
  @Matches(NUMERIC_STRING)
  pickup_latitude: string;

  @IsString()
  @Matches(NUMERIC_STRING)
  pickup_longitude: string;

  @IsString()
  @Matches(NUMERIC_STRING)
  delivery_latitude: string;

  @IsString()
  @Matches(NUMERIC_STRING)
  delivery_longitude: string;

  @IsOptional()
  @IsIn(['STRAIGHT_LINE', 'ROAD_ROUTE'])
  distance_method?: string;
}
