import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * POST /api/v1/auth/register — customer registration.
 * Validation rules ported 1:1 from Laravel AuthController::register.
 */
export class RegisterDto {
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
}