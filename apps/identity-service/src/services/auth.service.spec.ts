import { ForbiddenError, UnauthorizedError, ValidationError } from '@taladelivery/common';
import type { JwtPayload, TokenPair } from '@taladelivery/auth';
import { createHash } from 'node:crypto';
import { Repository } from 'typeorm';
import { RefreshToken } from '../entities/refresh-token.entity';
import { User } from '../entities/user.entity';
import { AuthService } from './auth.service';
import { UserService } from './user.service';
import { UserResourcesService } from './user-resources.service';
import type { TokenGateway, TokenSubject } from './token-gateway';

const NOW = new Date('2026-09-29T00:00:00.000Z');

const PAIR: TokenPair = {
  accessToken: 'access.jwt.example',
  refreshToken: 'refresh.jwt.example',
  accessTokenExpiresInSeconds: 900,
  refreshTokenExpiresInSeconds: 2592000,
  refreshTokenId: 'jti-1',
};

function seedUser(overrides: Partial<User> = {}): User {
  const user = new User();
  Object.assign(user, {
    id: 1,
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    phone: null,
    password: 'not-used',
    role: 'customer',
    status: 'ACTIVE',
    createdAt: NOW,
    updatedAt: NOW,
    ...overrides,
  });
  return user;
}

/**
 * Fakes the identity users repository (findOne/create/save/delete/count) so
 * the real UserService can run its email-uniqueness + bcrypt logic.
 */
function userRepo(seed: User[] = []) {
  const rows: User[] = [...seed];
  let nextId = rows.reduce((max, row) => Math.max(max, row.id), 0) + 1;
  const repo = {
    findOne: jest.fn(async ({ where }: { where: Record<string, unknown> }) => {
      for (const row of rows) {
        if (where.email !== undefined && row.email === where.email) return row;
        if (where.id !== undefined && row.id === where.id) return row;
      }
      return null;
    }),
    create: jest.fn((data: Partial<User>) => ({ ...data }) as User),
    save: jest.fn(async (user: User) => {
      if (user.id === undefined || user.id === 0) user.id = nextId++;
      user.createdAt = user.createdAt ?? NOW;
      user.updatedAt = NOW;
      const index = rows.findIndex((row) => row.id === user.id);
      if (index === -1) rows.push(user);
      else rows[index] = user;
      return user;
    }),
    delete: jest.fn(async (id: number | number[]) => {
      const ids = Array.isArray(id) ? id : [id];
      for (let i = rows.length - 1; i >= 0; i--) {
        if (ids.includes(rows[i].id)) rows.splice(i, 1);
      }
    }),
    count: jest.fn(async ({ where }: { where?: Record<string, unknown> } = {}) => {
      if (where?.role !== undefined) return rows.filter((row) => row.role === where.role).length;
      return rows.length;
    }),
    createQueryBuilder: jest.fn(),
  };
  return { repo: repo as unknown as Repository<User>, rows };
}

/** Fakes the refresh-token repository in memory. */
function refreshRepo(seed: RefreshToken[] = []) {
  const rows: RefreshToken[] = [...seed];
  let nextId = rows.reduce((max, row) => Math.max(max, row.id), 0) + 1;
  const repo = {
    findOne: jest.fn(async ({ where }: { where: Record<string, unknown> }) => {
      for (const row of rows) {
        if (where.jti !== undefined && row.jti === where.jti) return row;
        if (where.id !== undefined && row.id === where.id) return row;
      }
      return null;
    }),
    create: jest.fn((data: Partial<RefreshToken>) => ({ ...data }) as RefreshToken),
    save: jest.fn(async (row: RefreshToken) => {
      if (row.id === undefined || row.id === 0) row.id = nextId++;
      row.createdAt = row.createdAt ?? NOW;
      const index = rows.findIndex((existing) => existing.id === row.id);
      if (index === -1) rows.push(row);
      else rows[index] = row;
      return row;
    }),
    delete: jest.fn(async (id: number) => {
      let matched = false;
      for (let i = rows.length - 1; i >= 0; i--) {
        if (rows[i].id === id) {
          rows.splice(i, 1);
          matched = true;
        }
      }
      if (!matched && id !== undefined) {
        // RefreshToken.delete({ jti }) criteria path
        const criteria = id as unknown as { jti?: string };
        if (criteria.jti !== undefined) {
          for (let i = rows.length - 1; i >= 0; i--) {
            if (rows[i].jti === criteria.jti) rows.splice(i, 1);
          }
        }
      }
    }),
  };
  return { repo: repo as unknown as Repository<RefreshToken>, rows };
}

type MockTokenGateway = TokenGateway & {
  issuePair: jest.Mock;
  verifyAccess: jest.Mock;
  verifyRefresh: jest.Mock;
  getRefreshTtlSeconds: jest.Mock;
};

function fakeTokens(overrides: Partial<TokenGateway> = {}): MockTokenGateway {
  const tokens = {
    issuePair: jest.fn(async (_subject: TokenSubject, _tokenId?: string) => ({ ...PAIR })),
    verifyAccess: jest.fn(async (): Promise<JwtPayload> => ({
      sub: 1,
      email: 'ada@example.com',
      role: 'customer',
      status: 'ACTIVE',
      type: 'access',
      jti: PAIR.refreshTokenId,
    })),
    verifyRefresh: jest.fn(async (): Promise<JwtPayload> => ({
      sub: 1,
      email: 'ada@example.com',
      role: 'customer',
      status: 'ACTIVE',
      type: 'refresh',
      jti: PAIR.refreshTokenId,
    })),
    getRefreshTtlSeconds: jest.fn(() => 2592000),
  };
  return { ...tokens, ...overrides } as unknown as MockTokenGateway;
}

function setup(seedUsers: User[] = []) {
  const { repo: userRepository, rows: userRows } = userRepo(seedUsers);
  const { repo: refreshRepository, rows: refreshRows } = refreshRepo();
  const users = new UserService(userRepository);
  const resources = new UserResourcesService();
  const tokens = fakeTokens();
  const service = new AuthService(users, resources, tokens, refreshRepository);
  return { service, tokens, refreshRows, userRows, refreshRepository, users };
}

describe('AuthService', () => {
  describe('register', () => {
    it('creates an ACTIVE customer, hashes the password and returns a token pair + user JSON', async () => {
      const { service, tokens, refreshRows, userRows } = setup();

      const result = await service.register({
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'password123',
      });

      expect(result.token).toBe(PAIR.accessToken);
      expect(result.refresh_token).toBe(PAIR.refreshToken);
      expect(result.user).toMatchObject({
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        role: 'customer',
        status: 'ACTIVE',
      });

      const saved = userRows.find((row) => row.email === 'ada@example.com');
      expect(saved).not.toBeUndefined();
      expect(saved!.role).toBe('customer');
      expect(saved!.status).toBe('ACTIVE');
      // bcrypt hash, never the plaintext password
      expect(saved!.password).not.toBe('password123');
      expect(saved!.password.startsWith('$2')).toBe(true);

      expect(tokens.issuePair).toHaveBeenCalledTimes(1);
      const family = refreshRows.find((row) => row.jti === PAIR.refreshTokenId);
      expect(family).not.toBeUndefined();
      expect(family!.userId).toBe(saved!.id);
      expect(family!.tokenHash).toBe(createHash('sha256').update(PAIR.refreshToken).digest('hex'));
      expect(family!.revokedAt).toBeNull();
    });

    it('rejects a duplicate email with the Laravel-exact 422 message', async () => {
      const { service } = setup([seedUser()]);

      const error = await service
        .register({ name: 'Ada', email: 'ada@example.com', password: 'password123' })
        .catch((e: unknown) => e);

      expect(error).toBeInstanceOf(ValidationError);
      const validation = error as ValidationError;
      expect(validation.statusCode).toBe(422);
      expect(validation.errors).toEqual({ email: ['The email has already been taken.'] });
    });
  });

  describe('login', () => {
    it('returns a token pair for valid credentials', async () => {
      const initial = seedUser({
        password: '$2b$10$Nst/NTLzY.eH30.75w899.eCGhwpeA28sUBciQQxzJc97ocQjLYh6', // "password123"
      });
      const { service } = setup([initial]);

      const result = await service.login({ email: 'ada@example.com', password: 'password123' });

      expect(result.token).toBe(PAIR.accessToken);
      expect(result.user.email).toBe('ada@example.com');
    });

    it('throws UnauthorizedError for a wrong password or unknown email', async () => {
      const initial = seedUser({
        password: '$2b$10$Nst/NTLzY.eH30.75w899.eCGhwpeA28sUBciQQxzJc97ocQjLYh6',
      });
      const { service } = setup([initial]);

      await expect(
        service.login({ email: 'ada@example.com', password: 'wrong-password' }),
      ).rejects.toMatchObject({ statusCode: 401, message: 'Invalid credentials.' });
      await expect(
        service.login({ email: 'ghost@example.com', password: 'password123' }),
      ).rejects.toMatchObject({ statusCode: 401, message: 'Invalid credentials.' });
    });

    it('throws ForbiddenError when the account is not ACTIVE', async () => {
      const { service } = setup([
        seedUser({
          password: '$2b$10$Nst/NTLzY.eH30.75w899.eCGhwpeA28sUBciQQxzJc97ocQjLYh6',
          status: 'SUSPENDED',
        }),
      ]);

      const error = await service
        .login({ email: 'ada@example.com', password: 'password123' })
        .catch((e: unknown) => e);

      expect(error).toBeInstanceOf(ForbiddenError);
      expect((error as ForbiddenError).statusCode).toBe(403);
      expect((error as ForbiddenError).message).toBe('Your account is SUSPENDED.');
    });
  });

  describe('refresh', () => {
    it('rotates the refresh family: deletes the old row and issues a new pair', async () => {
      const initial = seedUser();
      const oldFamily = new RefreshToken();
      Object.assign(oldFamily, {
        id: 10,
        userId: 1,
        jti: 'old-jti',
        tokenHash: 'old-hash',
        expiresAt: new Date(NOW.getTime() + 2592000000),
        revokedAt: null,
        createdAt: NOW,
      });

      const { service, tokens, refreshRows } = setup([initial]);
      const { repo: refreshRepository } = refreshRepo([oldFamily]);
      // Rebuild the service bound to the pre-seeded refresh repo.
      const users = new UserService(userRepo([initial]).repo);
      const resources = new UserResourcesService();
      const serviceWithFamily = new AuthService(users, resources, tokens, refreshRepository);

      // refresh() reads the family by the jti in the (fake) refresh JWT.
      tokens.verifyRefresh.mockResolvedValue({
        sub: 1,
        email: 'ada@example.com',
        role: 'customer',
        status: 'ACTIVE',
        type: 'refresh',
        jti: 'old-jti',
      });

      const result = await serviceWithFamily.refresh(PAIR.refreshToken);

      expect(refreshRows.find((row) => row.jti === 'old-jti')).toBeUndefined();
      expect(result.token).toBe(PAIR.accessToken);
      expect(tokens.issuePair).toHaveBeenCalledTimes(1);
    });

    it('rejects an unknown/revoked refresh family with Unauthenticated', async () => {
      const { service, tokens } = setup([seedUser()]);
      tokens.verifyRefresh.mockResolvedValue({
        sub: 1,
        email: 'ada@example.com',
        role: 'customer',
        status: 'ACTIVE',
        type: 'refresh',
        jti: 'missing-jti',
      });

      await expect(service.refresh(PAIR.refreshToken)).rejects.toMatchObject({
        statusCode: 401,
        message: 'Unauthenticated.',
      });
    });
  });

  describe('logout', () => {
    it('revokes the refresh family tied to the presented access token', async () => {
      const initial = seedUser();
      const family = new RefreshToken();
      Object.assign(family, {
        id: 11,
        userId: 1,
        jti: PAIR.refreshTokenId,
        tokenHash: 'hash',
        expiresAt: new Date(NOW.getTime() + 2592000000),
        revokedAt: null,
        createdAt: NOW,
      });

      const { repo: refreshRepository, rows: refreshRows } = refreshRepo([family]);
      const service = new AuthService(
        new UserService(userRepo([initial]).repo),
        new UserResourcesService(),
        fakeTokens(),
        refreshRepository,
      );

      await service.logout('Bearer access.jwt.example');

      expect(refreshRows).toHaveLength(0);
    });
  });

  describe('me / updateProfile', () => {
    it('returns the Laravel UserResource for the current user', async () => {
      const { service } = setup([seedUser()]);

      const json = await service.me(1);

      expect(json).toMatchObject({
        id: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        roles: ['customer'],
        permissions: [],
        orders_count: 0,
        total_spent: 0,
      });
      expect(json.rider).toBeNull();
      expect(json.stores).toEqual([]);
    });

    it('updates the profile name/email/phone', async () => {
      const { service, userRows } = setup([seedUser()]);

      const json = await service.updateProfile(1, {
        name: 'Ada Byron',
        email: 'ada.byron@example.com',
        phone: '+639171234567',
      });

      expect(json.name).toBe('Ada Byron');
      expect(json.email).toBe('ada.byron@example.com');
      expect(userRows[0].phone).toBe('+639171234567');
    });

    it('keeps the Laravel-exact duplicate-email message while updating', async () => {
      const other = seedUser({ id: 7, email: 'taken@example.com' });
      const { service } = setup([seedUser(), other]);

      const error = await service
        .updateProfile(1, { name: 'Ada', email: 'taken@example.com' })
        .catch((e: unknown) => e);

      expect(error).toBeInstanceOf(ValidationError);
      expect((error as ValidationError).errors).toEqual({
        email: ['The email has already been taken.'],
      });
    });
  });
});
