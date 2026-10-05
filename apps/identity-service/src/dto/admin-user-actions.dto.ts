import { IsIn, IsNotEmpty, IsString, MinLength } from 'class-validator';
import { UserStatus } from '@taladelivery/contracts';

/**
 * PUT /api/v1/admin/users/:id/password — admin-provisioned password reset.
 *
 * Unlike a self-service change, this does NOT ask for the account's current
 * password: the caller already holds platform-admin authority, so the admin is
 * the recovery path for an admin who has lost theirs. Every existing refresh
 * family for the target is revoked, so any session signed in with the old
 * password stops working immediately rather than lingering until its 30-day TTL.
 */
export class ChangeAdminPasswordDto {
  @IsNotEmpty({ message: 'The password field is required.' })
  @IsString({ message: 'The password field must be a string.' })
  @MinLength(8, { message: 'The password field must be at least 8 characters.' })
  password: string;
}

/** PUT /api/v1/admin/users/:id/status — enable, disable or suspend an admin. */
export class UpdateAdminUserStatusDto {
  @IsIn([UserStatus.Active, UserStatus.Inactive, UserStatus.Suspended], {
    message: 'The selected status is invalid.',
  })
  status: string;
}