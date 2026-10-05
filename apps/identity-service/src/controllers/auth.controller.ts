import {
  Body,
  Controller,
  Get,
  Headers,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import { Message } from '@taladelivery/common';
import { AuthService } from '../services/auth.service';
import { LoginDto } from '../dto/login.dto';
import { RefreshTokenDto } from '../dto/refresh-token.dto';
import { RegisterDto } from '../dto/register.dto';
import { UpdateProfileDto } from '../dto/update-profile.dto';

/**
 * Auth endpoints (mirrors Laravel AuthController + Phase 3 additions):
 * customer register/login are public; refresh rotates JWTs; logout/me/profile
 * require a valid access token. Laravel Sanctum is replaced by JWT + refresh
 * tokens, so register/login also return `refresh_token`.
 */
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @UseGuards(AppKeyGuard)
  @Message('Registration successful.')
  async register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  @UseGuards(AppKeyGuard)
  @Message('Login successful.')
  async login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Post('refresh')
  @UseGuards(AppKeyGuard)
  @Message('Token refreshed.')
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.auth.refresh(dto.refresh_token);
  }

  @Post('logout')
  @UseGuards(AppKeyGuard, JwtAuthGuard)
  @Message('Logged out successfully.')
  async logout(@Headers('authorization') authorization: string | undefined) {
    const token = stripBearer(authorization);
    await this.auth.logout(token);
    return null;
  }

  @Get('me')
  @UseGuards(AppKeyGuard, JwtAuthGuard)
  @Message('Authenticated user.')
  async me(@CurrentUser() user: JwtPayload) {
    return this.auth.me(user.sub);
  }

  @Put('profile')
  @UseGuards(AppKeyGuard, JwtAuthGuard)
  @Message('Profile updated successfully.')
  async updateProfile(@CurrentUser() user: JwtPayload, @Body() dto: UpdateProfileDto) {
    return this.auth.updateProfile(user.sub, dto);
  }
}

function stripBearer(authorization: string | undefined): string {
  if (authorization === undefined || !authorization.startsWith('Bearer ')) return '';
  return authorization.slice('Bearer '.length).trim();
}