import type { Role, UserStatus } from '@taladelivery/contracts';

export const JWT_TYPE_ACCESS = 'access';
export const JWT_TYPE_REFRESH = 'refresh';

export interface JwtPayload {
  /** user id */
  sub: number;
  email: string;
  role: Role;
  status: UserStatus;
  /** access | refresh */
  type: typeof JWT_TYPE_ACCESS | typeof JWT_TYPE_REFRESH;
  /** unique token id (used to link refresh tokens to DB rows) */
  jti: string;
  /** name of the token family, e.g. "auth-token" */
  tokenName?: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresInSeconds: number;
  refreshTokenExpiresInSeconds: number;
  refreshTokenId: string;
}

export function parseJtiFromToken(jwtToken: string): string | null {
  // JWT has three dot-separated segments; payload is base64url.
  const parts = jwtToken.split('.');
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(
      Buffer.from(parts[1], 'base64url').toString('utf8'),
    ) as { jti?: string };
    return payload.jti ?? null;
  } catch {
    return null;
  }
}