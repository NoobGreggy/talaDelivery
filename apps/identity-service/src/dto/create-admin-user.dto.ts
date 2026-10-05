import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { UserStatus } from '@taladelivery/contracts';

/**
 * POST /api/v1/admin/users — admin-provisioned platform-admin account.
 *
 * Deliberately has no `role` field. The only role this endpoint can grant is
 * `platform_admin`; `store_admin` accounts additionally need a `store_users`
 * membership row that only merchant-service can write, so creating one here
 * would yield an account that cannot reach its own store.
 *
 * The password is required rather than generated. It arrives already hashed by
 * `UserService.create` and is never echoed back in the response.
 */
export class CreateAdminUserDto {
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

  /** Defaults to ACTIVE, so a new admin can sign in immediately. */
  @IsOptional()
  @IsIn([UserStatus.Active, UserStatus.Inactive, UserStatus.Suspended], {
    message: 'The selected status is invalid.',
  })
  status?: string;
}