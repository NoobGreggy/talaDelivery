import { ValidationError } from '@taladelivery/common';
import { plainToInstance } from 'class-transformer';
import {
  getMetadataStorage,
  validateSync,
  type ValidationError as CvValidationError,
} from 'class-validator';
import { CreateAdminUserDto } from './create-admin-user.dto';
import { UserService } from '../services/user.service';

const NOW = new Date('2026-09-29T00:00:00.000Z');

function seedUser(overrides: Partial<Record<string, unknown>> = {}): Record<string, unknown> {
  return {
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
  };
}

/** Fakes just the write path `UserService.create` needs. */
function userRepo() {
  const rows: Record<string, unknown>[] = [];
  let nextId = 1;
  return {
    repo: {
      findOne: jest.fn(async ({ where }: { where: Record<string, unknown> }) =>
        rows.find((row) => Object.entries(where).every(([k, v]) => row[k] === v)) ?? null,
      ),
      create: jest.fn((data: Record<string, unknown>) => ({ ...data })),
      save: jest.fn(async (user: Record<string, unknown>) => {
        user.id = nextId++;
        user.createdAt = NOW;
        rows.push(user);
        return user;
      }),
    } as never,
    rows,
  };
}

describe('CreateAdminUserDto', () => {
  function check(payload: Record<string, unknown>) {
    return validateSync(plainToInstance(CreateAdminUserDto, payload));
  }

  /**
   * Flattened `{ field: [messages] }` shape, matching what the global
   * Laravel-shaped pipe puts into the 422 body. `constraints` alone would lose
   * the field name.
   */
  function messagesOf(errors: CvValidationError[]): Record<string, string[]> {
    const out: Record<string, string[]> = {};
    for (const error of errors) {
      out[error.property] = Object.values(error.constraints ?? {});
    }
    return out;
  }

  it('accepts a valid payload', () => {
    const errors = check({
      name: 'Grace Hopper',
      email: 'grace@example.com',
      password: 'Pass@123456',
    });

    expect(errors).toHaveLength(0);
  });

  it('accepts every valid status', () => {
    for (const status of ['ACTIVE', 'INACTIVE', 'SUSPENDED']) {
      expect(
        check({ name: 'G', email: 'g@example.com', password: 'Pass@123456', status }),
      ).toHaveLength(0);
    }
  });

  it('rejects an invalid email with the Laravel message', () => {
    const errors = check({ name: 'G', email: 'not-an-email', password: 'Pass@123456' });

    expect(messagesOf(errors)['email']).toContain('The email field must be a valid email address.');
  });

  it('rejects a password under 8 characters', () => {
    const errors = check({ name: 'G', email: 'g@example.com', password: 'short' });

    expect(messagesOf(errors)['password']).toContain(
      'The password field must be at least 8 characters.',
    );
  });

  it('rejects a missing password entirely', () => {
    const errors = check({ name: 'G', email: 'g@example.com' });

    expect(messagesOf(errors)['password']).toContain('The password field is required.');
  });

  it('rejects an unknown status', () => {
    const errors = check({
      name: 'G',
      email: 'g@example.com',
      password: 'Pass@123456',
      status: 'BOGUS',
    });

    expect(messagesOf(errors)['status']).toEqual(['The selected status is invalid.']);
  });

  it('does not validate a role field at all', () => {
    const errors = check({
      name: 'G',
      email: 'g@example.com',
      password: 'Pass@123456',
      role: 'definitely_not_a_role',
    });

    // No `role` validator exists, so an arbitrary value raises no error. It is
    // also never consumed: the controller hard-codes Role.PlatformAdmin.
    expect(messagesOf(errors)).toEqual({});
  });

  it('validates only the intended fields, with no role among them', () => {
    // TS class fields with no initializer live on the instance, not the
    // prototype, so read the decorator metadata that class-validator uses for
    // `whitelist: true` instead.
    const validated = getMetadataStorage().getTargetValidationMetadatas(
      CreateAdminUserDto,
      CreateAdminUserDto.name,
      true,
      false,
    );
    const properties = new Set(validated.map((meta) => meta.propertyName));

    expect([...properties].sort()).toEqual(['email', 'name', 'password', 'phone', 'status']);
    expect(properties.has('role')).toBe(false);
  });
});

// The controller always passes Role.PlatformAdmin explicitly; this asserts the
// repository-visible outcome of that pairing rather than the DTO alone.
describe('admin user creation persistence', () => {
  it('hashes the password and stores platform_admin', async () => {
    const { repo, rows } = userRepo();
    const service = new UserService(repo);

    const created = await service.create({
      name: 'Grace Hopper',
      email: seedUser().email as string,
      password: 'Pass@123456',
      role: 'platform_admin',
      status: 'ACTIVE',
    });

    expect(created.role).toBe('platform_admin');
    expect(rows[0].password).not.toBe('Pass@123456');
    expect(String(rows[0].password).startsWith('$2')).toBe(true);
  });

  it('rejects a duplicate email with the Laravel-exact 422', async () => {
    const { repo } = userRepo();
    const service = new UserService(repo);

    await service.create({
      name: 'First',
      email: 'dupe@example.com',
      password: 'Pass@123456',
      role: 'platform_admin',
      status: 'ACTIVE',
    });

    const error = await service
      .create({
        name: 'Second',
        email: 'dupe@example.com',
        password: 'Pass@123456',
        role: 'platform_admin',
        status: 'ACTIVE',
      })
      .catch((e: unknown) => e);

    expect(error).toBeInstanceOf(ValidationError);
    expect((error as ValidationError).statusCode).toBe(422);
    expect((error as ValidationError).errors).toEqual({
      email: ['The email has already been taken.'],
    });
  });
});