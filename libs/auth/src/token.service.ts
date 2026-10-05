import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, type JwtSignOptions } from '@nestjs/jwt';
import { randomUUID } from 'node:crypto';
import { UnauthorizedError } from '@taladelivery/common/errors';
import type { Role, UserStatus } from '@taladelivery/contracts';
import {
  JWT_TYPE_ACCESS,
  JWT_TYPE_REFRESH,
  type JwtPayload,
  type TokenPair,
} from './jwt-payload';

export interface TokenSubject {
  id: number;
  email: string;
  role: Role;
  status: UserStatus;
}

@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  private get accessSecret(): string {
    return this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
  }

  private get accessTtl(): string {
    return this.config.get<string>('JWT_ACCESS_TTL', '15m');
  }

  private get refreshSecret(): string {
    return this.config.getOrThrow<string>('JWT_REFRESH_SECRET');
  }

  private get refreshTtlSeconds(): number {
    return parseTtlToSeconds(this.config.get<string>('JWT_REFRESH_TTL', '30d'));
  }

  getRefreshTtlSeconds(): number {
    return this.refreshTtlSeconds;
  }

  async issuePair(subject: TokenSubject, tokenId?: string): Promise<TokenPair> {
    const jti = tokenId ?? randomUUID();
    const accessPayload: JwtPayload = {
      sub: subject.id,
      email: subject.email,
      role: subject.role,
      status: subject.status,
      type: JWT_TYPE_ACCESS,
      jti,
      tokenName: 'auth-token',
    };

    const refreshPayload: JwtPayload = {
      ...accessPayload,
      type: JWT_TYPE_REFRESH,
    };

    const algorithm = this.config.get('JWT_ALGORITHM', 'HS256');
    const accessToken = await this.jwt.signAsync(accessPayload, {
      secret: this.accessSecret,
      expiresIn: this.accessTtl as unknown as JwtSignOptions['expiresIn'],
      algorithm: algorithm as JwtSignOptions['algorithm'],
    });
    const refreshToken = await this.jwt.signAsync(refreshPayload, {
      secret: this.refreshSecret,
      expiresIn: this.refreshTtlSeconds,
      algorithm: algorithm as JwtSignOptions['algorithm'],
    });

    return {
      accessToken,
      refreshToken,
      accessTokenExpiresInSeconds: parseTtlToSeconds(this.accessTtl),
      refreshTokenExpiresInSeconds: this.refreshTtlSeconds,
      refreshTokenId: jti,
    };
  }

  /** Verifies an access token. Throws UnauthorizedError on any failure. */
  async verifyAccess(token: string): Promise<JwtPayload> {
    return this.verify(token, this.accessSecret, JWT_TYPE_ACCESS);
  }

  /** Verifies a refresh token. Throws UnauthorizedError on any failure. */
  async verifyRefresh(token: string): Promise<JwtPayload> {
    return this.verify(token, this.refreshSecret, JWT_TYPE_REFRESH);
  }

  private async verify(token: string, secret: string, expectedType: string): Promise<JwtPayload> {
    if (!token) {
      throw new UnauthorizedError('Unauthenticated.');
    }
    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, { secret });
      if (payload.type !== expectedType) {
        throw new UnauthorizedError('Unauthenticated.');
      }
      return payload;
    } catch {
      throw new UnauthorizedError('Unauthenticated.');
    }
  }
}

export function parseTtlToSeconds(ttl: string): number {
  const match = /^(\d+)([smhd]?)$/.exec(ttl);
  if (!match) return 900;
  const amount = Number.parseInt(match[1], 10);
  switch (match[2]) {
    case 's':
      return amount;
    case 'm':
      return amount * 60;
    case 'h':
      return amount * 3600;
    case 'd':
      return amount * 86400;
    default:
      return amount;
  }
}