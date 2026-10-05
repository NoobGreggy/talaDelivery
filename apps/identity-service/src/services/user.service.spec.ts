import { ValidationError } from '@taladelivery/common';
import { User } from '../entities/user.entity';
import { UserService } from './user.service';

const NOW = new Date('2026-09-29T00:00:00.000Z');

function seedUser(overrides: Partial<User> = {}): User {
  const user = new User();
  Object.assign(user, {
    id: 1,
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    phone: null,
    password: 'hash',
    role: 'platform_admin',
    status: 'ACTIVE',
    createdAt: NOW,
    updatedAt: NOW,
    ...overrides,
  });
  return user;
}

function userRepo(seed: User[] = []) {
  const rows = [...seed];
  let nextId = rows.reduce((max, row) => Math.max(max, row.id), 0) + 1;
  const repo = {
    findOne: jest.fn(async ({ where }: { where: Record<string, unknown> }) =>
      rows.find((row) => Object.entries(where).every(([k, v]) => (row as never)[k] === v)) ?? null,
    ),
    create: jest.fn((data: Partial<User>) => ({ ...data }) as User),
    save: jest.fn(async (user: User) => {
      if (user.id === undefined) user.id = nextId++;
      user.updatedAt = NOW;
      const index = rows.findIndex((row) => row.id === user.id);
      if (index === -1) rows.push(user);
      else rows[index] = user;
      return user;
    }),
  };
  return { repo: repo as never, rows };
}

function setup(seed: User[] = []) {
  const stub = userRepo(seed);
  return { service: new UserService(stub.repo), rows: stub.rows };
}

describe('UserService.setPassword', () => {
  it('hashes and persists the new password, never the plaintext', async () => {
    const { service, rows } = setup([seedUser()]);

    const updated = await service.setPassword(rows[0], 'Pass@123456');

    expect(updated.password).not.toBe('Pass@123456');
    expect(updated.password.startsWith('$2')).toBe(true);
  });

  it('makes the new password verify', async () => {
    const { service, rows } = setup([seedUser()]);

    await service.setPassword(rows[0], 'Pass@123456');

    expect(await service.verifyCredentials('ada@example.com', 'Pass@123456')).not.toBeNull();
  });

  it('stops verifying the old password', async () => {
    const initial = seedUser({
      password: '$2b$10$Nst/NTLzY.eH30.75w899.eCGhwpeA28sUBciQQxzJc97ocQjLYh6', // "password123"
    });
    const { service, rows } = setup([initial]);

    await service.setPassword(rows[0], 'Pass@123456');

    expect(await service.verifyCredentials('ada@example.com', 'password123')).toBeNull();
  });
});

describe('UserService.setStatus', () => {
  it('persists the new status', async () => {
    const { service, rows } = setup([seedUser()]);

    const updated = await service.setStatus(rows[0], 'INACTIVE');

    expect(updated.status).toBe('INACTIVE');
  });

  it('can move an account out of and back into ACTIVE', async () => {
    const { service, rows } = setup([seedUser()]);

    await service.setStatus(rows[0], 'SUSPENDED');
    expect(rows[0].status).toBe('SUSPENDED');

    await service.setStatus(rows[0], 'ACTIVE');
    expect(rows[0].status).toBe('ACTIVE');
  });
});