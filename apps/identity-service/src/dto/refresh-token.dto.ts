import { IsNotEmpty, IsString } from 'class-validator';

/**
 * POST /api/v1/auth/refresh — the NestJS JWT architecture rotates refresh
 * tokens (nestjs_api.md Phase 3). No Laravel equivalent.
 */
export class RefreshTokenDto {
  @IsNotEmpty({ message: 'The refresh token field is required.' })
  @IsString({ message: 'The refresh token field must be a string.' })
  refresh_token: string;
}