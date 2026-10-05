import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/**
 * PUT /api/v1/auth/profile — validation rules ported 1:1 from Laravel
 * AuthController::updateProfile (unique email is checked in the service,
 * excluding the current user, mirroring Rule::unique(...)->ignore($user->id)).
 */
export class UpdateProfileDto {
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
}