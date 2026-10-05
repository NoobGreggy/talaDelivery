import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  ForbiddenError,
  UnauthorizedError,
} from '@taladelivery/common';
import type { JwtPayload, TokenPair } from '@taladelivery/auth';
import { RefreshToken } from '../entities/refresh-token.entity';
import { User } from '../entities/user.entity';
import { hashToken } from './user.service';
import { UserService } from './user.service';
import { TokenGateway, type TokenSubject } from './token-gateway';
import { UserResourcesService, type UserResourceJson } from './user-resources.service';

export interface AuthResult {
  token: string;
  refresh_token: string;
  user: UserResourceJson;
}

/**
 * Authentication (`register`, `login`, `refresh`, `logout`, `profile`).
 * Access/refresh JWTs are issued by @taladelivery/auth TokenService; the
 * refresh-token family is persisted locally so it can be rotated/revoked.
 */
@Injectable()
export class AuthService {
  constructor(
    private readonly users: UserService,
    private readonly resources: UserResourcesService,
    private readonly tokens: TokenGateway,
    @InjectRepository(RefreshToken) private readonly refreshTokens: Repository<RefreshToken>,
  ) {}

  async register(dto: {
    name: string;
    email: string;
    phone?: string | null;
    password: string;
  }): Promise<AuthResult> {
    const user = await this.users.create({
      name: dto.name,
      email: dto.email,
      phone: dto.phone ?? null,
      password: dto.password,
      role: 'customer',
      status: 'ACTIVE',
    });
    return this.respondWithTokens(user);
  }

  async login(dto: { email: string; password: string }): Promise<AuthResult> {
    const user = await this.users.verifyCredentials(dto.email, dto.password);
    if (user === null) {
      throw new UnauthorizedError('Invalid credentials.');
    }
    if (user.status !== 'ACTIVE') {
      throw new ForbiddenError(`Your account is ${user.status}.`);
    }
    return this.respondWithTokens(user);
  }

  /**
   * Refresh-token rotation: validates the refresh JWT, confirms the family is
   * still recorded and unrevoked, then issues a new pair with a fresh jti.
   */
  async refresh(refreshToken: string): Promise<AuthResult> {
    const payload = await this.verifyRefreshToken(refreshToken);
    const family = await this.refreshTokens.findOne({ where: { jti: payload.jti } });
    if (family === null || family.revokedAt !== null) {
      throw new UnauthorizedError('Unauthenticated.');
    }
    const user = await this.users.findById(payload.sub);
    if (user === null) {
      throw new UnauthorizedError('Unauthenticated.');
    }
    await this.refreshTokens.delete({ id: family.id });
    return this.respondWithTokens(user);
  }

  /**
   * Revokes every refresh-token family for a user. Called after an admin
   * password reset or a status change so existing sessions stop refreshing
   * immediately instead of surviving until their 30-day TTL expires.
   */
  async revokeSessions(userId: number): Promise<void> {
    await this.refreshTokens.delete({ userId });
  }

  /** Revokes the refresh-token family tied to the presented access token. */
  async logout(accessToken: string): Promise<void> {
    const payload = await this.tokens.verifyAccess(accessToken);
    await this.refreshTokens.delete({ jti: payload.jti });
  }

  async me(userId: number): Promise<UserResourceJson> {
    const user = await this.requireUser(userId);
    return this.resources.toUserJson(user);
  }

  async updateProfile(
    userId: number,
    dto: { name: string; email: string; phone?: string | null },
  ): Promise<UserResourceJson> {
    const user = await this.requireUser(userId);
    const updated = await this.users.updateProfile(user, dto);
    return this.resources.toUserJson(updated);
  }

  /** Issues a token pair + user JSON, persisting the refresh family. */
  private async respondWithTokens(user: User): Promise<AuthResult> {
    const pair = await this.issuePair(user);
    return {
      token: pair.accessToken,
      refresh_token: pair.refreshToken,
      user: this.resources.toUserJson(user),
    };
  }

  private async issuePair(user: User): Promise<TokenPair> {
    const subject: TokenSubject = {
      id: user.id,
      email: user.email,
      role: user.role as TokenSubject['role'],
      status: user.status as TokenSubject['status'],
    };
    const pair = await this.tokens.issuePair(subject);
    await this.refreshTokens.save(
      this.refreshTokens.create({
        userId: user.id,
        jti: pair.refreshTokenId,
        tokenHash: hashToken(pair.refreshToken),
        expiresAt: new Date(Date.now() + this.tokens.getRefreshTtlSeconds() * 1000),
        revokedAt: null,
      }),
    );
    return pair;
  }

  private async verifyRefreshToken(token: string): Promise<JwtPayload> {
    try {
      return await this.tokens.verifyRefresh(token);
    } catch {
      throw new UnauthorizedError('Unauthenticated.');
    }
  }

  private async requireUser(userId: number): Promise<User> {
    const user = await this.users.findById(userId);
    if (user === null) {
      throw new UnauthorizedError('Unauthenticated.');
    }
    return user;
  }
}