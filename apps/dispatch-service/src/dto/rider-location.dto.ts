import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

/**
 * POST /v1/rider/location (mirrors Laravel RiderController::location rules).
 * `delivery_id` is the dispatch delivery row the rider is assigned to.
 */
export class RiderLocationDto {
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @Type(() => Number)
  @IsOptional()
  @IsInt()
  delivery_id?: number;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1000)
  accuracy_m?: number;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(360)
  heading_deg?: number;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  speed_mps?: number;

  @IsOptional()
  @IsDateString()
  recorded_at?: string;
}