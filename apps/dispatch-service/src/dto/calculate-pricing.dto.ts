import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayUnique, IsArray, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

/**
 * Internal POST /internal/pricing/calculate (order-service calls dispatch to
 * price a quote). Pickup defaults to nullable so the caller can omit them and
 * receive the Laravel-exact validation error.
 */
export class CalculatePricingDto {
  @IsOptional() @IsArray() @ArrayMaxSize(50) @ArrayUnique() @IsInt({ each: true }) @Min(1, { each: true })
  allowedZoneIds?: number[];
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  pickupLatitude?: number | null;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  pickupLongitude?: number | null;

  @Type(() => Number)
  @IsNumber()
  deliveryLatitude: number;

  @Type(() => Number)
  @IsNumber()
  deliveryLongitude: number;

  @IsOptional()
  @IsString()
  city?: string | null;

  @IsOptional()
  @IsString()
  province?: string | null;
}
