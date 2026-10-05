import { IsEmail, IsNotEmpty, IsString } from 'class-validator';

/**
 * POST /api/v1/auth/login — validation rules ported 1:1 from Laravel
 * AuthController::login.
 */
export class LoginDto {
  @IsNotEmpty({ message: 'The email field is required.' })
  @IsString({ message: 'The email field must be a string.' })
  @IsEmail({}, { message: 'The email field must be a valid email address.' })
  email: string;

  @IsNotEmpty({ message: 'The password field is required.' })
  @IsString({ message: 'The password field must be a string.' })
  password: string;
}