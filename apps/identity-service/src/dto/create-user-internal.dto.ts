import { IsIn, IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { Role, UserStatus } from '@taladelivery/contracts';

/**
 * Internal POST /internal/users (contracts §1.1). Called by other services to
 * provision users in the identity DB.
 */
export class CreateUserInternalDto {
  @IsNotEmpty({ message: 'The name field is required.' })
  @IsString({ message: 'The name field must be a string.' })
  @MaxLength(255, { message: 'The name field must not be greater than 255 characters.' })
  name: string;

  @IsNotEmpty({ message: 'The email field is required.' })
  @IsString({ message: 'The email field must be a string.' })
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

  @IsIn([Role.PlatformAdmin, Role.StoreAdmin, Role.Rider, Role.Customer], {
    message: 'The selected role is invalid.',
  })
  role: string;

  @IsIn([UserStatus.Active, UserStatus.Inactive, UserStatus.Suspended], {
    message: 'The selected status is invalid.',
  })
  status: string;
}