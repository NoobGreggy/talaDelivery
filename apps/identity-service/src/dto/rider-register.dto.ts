import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { VehicleType } from '@taladelivery/contracts';

/**
 * POST /api/v1/rider/register (contracts §4). Validation rules ported 1:1 from
 * Laravel RiderController::register (vehicle/rider-profile fields included).
 */
export class RiderRegisterDto {
  @IsNotEmpty({ message: 'The name field is required.' })
  @IsString({ message: 'The name field must be a string.' })
  @MaxLength(255, { message: 'The name field must not be greater than 255 characters.' })
  name: string;

  @IsNotEmpty({ message: 'The email field is required.' })
  @IsString({ message: 'The email field must be a string.' })
  @IsEmail({}, { message: 'The email field must be a valid email address.' })
  @MaxLength(255, { message: 'The email field must not be greater than 255 characters.' })
  email: string;

  @IsOptional()
  @IsString({ message: 'The phone field must be a string.' })
  @MaxLength(20, { message: 'The phone field must not be greater than 20 characters.' })
  phone?: string | null;

  @IsNotEmpty({ message: 'The password field is required.' })
  @IsString({ message: 'The password field must be a string.' })
  @MinLength(8, { message: 'The password field must be at least 8 characters.' })
  password: string;

  @IsNotEmpty({ message: 'The vehicle type field is required.' })
  @IsString({ message: 'The vehicle type field must be a string.' })
  @IsIn(
    [VehicleType.Motorcycle, VehicleType.Bicycle, VehicleType.Car],
    { message: 'The selected vehicle type is invalid.' },
  )
  vehicle_type: string;

  @IsOptional()
  @IsString({ message: 'The vehicle plate field must be a string.' })
  @MaxLength(20, { message: 'The vehicle plate field must not be greater than 20 characters.' })
  vehicle_plate?: string | null;

  @IsOptional()
  @IsString({ message: 'The license number field must be a string.' })
  @MaxLength(50, { message: 'The license number field must not be greater than 50 characters.' })
  license_number?: string | null;

  @IsOptional()
  @IsObject({ message: 'The requirements field must be an array.' })
  requirements?: Record<string, unknown> | null;
}