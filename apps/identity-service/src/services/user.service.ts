import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ValidationError } from '@taladelivery/common';
import { Role, UserStatus, type UserSnapshot } from '@taladelivery/contracts';
import { createHash } from 'node:crypto';
import * as bcrypt from 'bcryptjs';
import { User } from '../entities/user.entity';

export interface CreateUserInput {
  name: string;
  email: string;
  phone?: string | null;
  password: string;
  role: string;
  status: string;
}

/**
 * User persistence + credential hashing. Uniqueness on email mirrors Laravel's
 * `unique:users,email` rule (message keeps the Laravel-exact wording).
 */
@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  async findById(id: number): Promise<User | null> {
    return this.users.findOne({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.users.findOne({ where: { email } });
  }

  async findByIds(ids: number[]): Promise<User[]> {
    if (ids.length === 0) return [];
    return this.users
      .createQueryBuilder('user')
      .where('user.id IN (:...ids)', { ids })
      .orderBy('user.id', 'ASC')
      .getMany();
  }

  async countByRole(role: string): Promise<number> {
    return this.users.count({ where: { role } });
  }

  /**
   * Paginated customer listing for the admin console. Newest first (matching
   * the admin rider/delivery lists) so a freshly registered customer is
   * visible without scrolling. `search` spans name/email/phone; `status`
   * narrows to one lifecycle state.
   */
  async listByRole(
    role: string,
    opts: { page: number; perPage: number; search?: string; status?: string },
  ): Promise<{ items: User[]; total: number }> {
    const query = this.users
      .createQueryBuilder('user')
      .where('user.role = :role', { role })
      .orderBy('user.created_at', 'DESC')
      .addOrderBy('user.id', 'DESC')
      .skip((opts.page - 1) * opts.perPage)
      .take(opts.perPage);

    if (opts.status !== undefined && opts.status !== '') {
      query.andWhere('user.status = :status', { status: opts.status });
    }
    if (opts.search !== undefined && opts.search !== '') {
      const term = `%${opts.search}%`;
      query.andWhere(
        '(user.name ILIKE :term OR user.email ILIKE :term OR user.phone ILIKE :term)',
        { term },
      );
    }

    const [items, total] = await query.getManyAndCount();
    return { items, total };
  }

  /**
   * Active users holding a role. Used to address platform-wide notifications
   * (e.g. a new rider application) without a cross-service lookup — identity
   * owns the users table.
   */
  async findActiveByRole(role: string): Promise<User[]> {
    return this.users.find({
      where: { role, status: UserStatus.Active },
      order: { id: 'ASC' },
    });
  }

  async delete(userId: number): Promise<void> {
    await this.users.delete(userId);
  }

  async emailTaken(email: string, excludeUserId?: number): Promise<boolean> {
    const existing = await this.findByEmail(email);
    if (existing === null) return false;
    return excludeUserId === undefined || existing.id !== excludeUserId;
  }

  /**
   * Creates a user. Throws a Laravel-exact 422 when the email is already in
   * use (validation `unique:users,email`).
   */
  async create(input: CreateUserInput): Promise<User> {
    if (await this.emailTaken(input.email)) {
      throw new ValidationError('The given data was invalid.', {
        email: ['The email has already been taken.'],
      });
    }
    const user = this.users.create({
      name: input.name,
      email: input.email,
      phone: input.phone ?? null,
      password: await this.hashPassword(input.password),
      role: input.role,
      status: input.status,
    });
    return this.users.save(user);
  }

  /**
   * Updates profile fields; unique email validation excludes the current user
   * (mirrors Laravel Rule::unique(...)->ignore($user->id)).
   */
  async updateProfile(
    user: User,
    data: { name: string; email: string; phone?: string | null },
  ): Promise<User> {
    if (await this.emailTaken(data.email, user.id)) {
      throw new ValidationError('The given data was invalid.', {
        email: ['The email has already been taken.'],
      });
    }
    user.name = data.name;
    user.email = data.email;
    user.phone = data.phone ?? null;
    return this.users.save(user);
  }

  /**
   * Admin password reset. Hashes and persists the new password; the caller is
   * responsible for revoking sessions (see `AuthService.revokeSessions`).
   */
  async setPassword(user: User, password: string): Promise<User> {
    user.password = await this.hashPassword(password);
    return this.users.save(user);
  }

  /**
   * Admin status change (enable/disable/suspend). `AuthService.login` already
   * refuses any non-ACTIVE account, so flipping the status here is enough to
   * cut off future sign-ins.
   */
  async setStatus(user: User, status: string): Promise<User> {
    user.status = status;
    return this.users.save(user);
  }

  /** Returns the user only when the password matches (login check). */
  async verifyCredentials(email: string, password: string): Promise<User | null> {
    const user = await this.findByEmail(email);
    if (user === null) return null;
    const matches = await bcrypt.compare(password, user.password);
    return matches ? user : null;
  }

  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }

  toUserSnapshot(user: User): UserSnapshot {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone ?? null,
      role: user.role as UserSnapshot['role'],
      status: user.status as UserSnapshot['status'],
    };
  }
}

/** sha256 helper for storing refresh-token fingerprints. */
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Convenience role/status constants kept near the create input. */
export const DEFAULT_CUSTOMER = {
  role: Role.Customer,
  status: UserStatus.Active,
} as const;

export const DEFAULT_RIDER = {
  role: Role.Rider,
  status: UserStatus.Active,
} as const;