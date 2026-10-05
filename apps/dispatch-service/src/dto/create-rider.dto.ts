import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { VehicleType } from '@taladelivery/contracts';

/**
 * Internal POST /internal/riders (identity-service creates the user first;
 * dispatch creates the rider profile row keyed by the identity user id).
 */
export class CreateRiderDto {
  @Type(() => Number)
  @IsInt()
  userId: number;

  @IsIn([VehicleType.Motorcycle, VehicleType.Bicycle, VehicleType.Car])
  vehicleType: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  vehiclePlate?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  licenseNumber?: string | null;

  @IsOptional()
  @IsObject()
  requirements?: Record<string, unknown> | null;
}