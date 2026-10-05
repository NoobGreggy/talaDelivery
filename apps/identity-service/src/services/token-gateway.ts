import type { JwtPayload, TokenPair } from '@taladelivery/auth';
import type { Role, UserStatus } from '@taladelivery/contracts';

export interface TokenSubject {
  id: number;
  email: string;
  role: Role;
  status: UserStatus;
}

/**
 * Narrow view of `@taladelivery/auth`'s TokenService so service specs can fake
 * token operations without loading `@nestjs/jwt` (pure ESM) at Jest runtime.
 * app.module.ts binds this to the real TokenService via `useExisting`.
 */
export abstract class TokenGateway {
  abstract issuePair(subject: TokenSubject, tokenId?: string): Promise<TokenPair>;
  abstract verifyAccess(token: string): Promise<JwtPayload>;
  abstract verifyRefresh(token: string): Promise<JwtPayload>;
  abstract getRefreshTtlSeconds(): number;
}