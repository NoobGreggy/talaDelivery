import { Body, Controller, Get, Param, ParseIntPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  Roles,
  RolesGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import {
  ForbiddenError,
  Message,
  NotFoundError,
  PaginatedResult,
  ValidationError,
  requestContext,
  resolvePagination,
} from '@taladelivery/common';
import { Role, UserStatus } from '@taladelivery/contracts';
import { UserService } from '../../services/user.service';
import type { User } from '../../entities/user.entity';
import { AuthService } from '../../services/auth.service';
import { UserResourcesService } from '../../services/user-resources.service';
import { CreateAdminUserDto } from '../../dto/create-admin-user.dto';
import {
  ChangeAdminPasswordDto,
  UpdateAdminUserStatusDto,
} from '../../dto/admin-user-actions.dto';
import { squish } from '../../common/format.util';

/**
 * Admin user management for platform-admin accounts.
 *
 * Guards: X-App-Key + JWT + platform_admin. Only platform admins can reach
 * this, so an account created here is always platform_admin too — the DTO has
 * no `role` field to widen it. That keeps privilege escalation impossible from
 * this endpoint: the caller already holds full platform access, and no request
 * can mint a role above the caller's own.
 *
 * A store_admin additionally needs a `store_users` membership row, which only
 * merchant-service owns, so store admins are still provisioned through that
 * service's internal contract.
 */
@Controller('admin/users')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminUserController {
  constructor(
    private readonly users: UserService,
    private readonly auth: AuthService,
    private readonly resources: UserResourcesService,
  ) {}

  @Get()
  @Message('Users retrieved.')
  async index(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const term = search === undefined ? undefined : squish(search);

    const { items, total } = await this.users.listByRole(Role.PlatformAdmin, {
      page: p,
      perPage: pp,
      search: term === '' ? undefined : term,
      status,
    });

    return new PaginatedResult(
      items.map((user) => this.resources.toUserJson(user)),
      {
        currentPage: p,
        lastPage: Math.max(1, Math.ceil(total / pp)),
        perPage: pp,
        total,
        path: requestContext().path,
      },
    );
  }

  @Get(':id')
  @Message('User retrieved.')
  async show(@Param('id', ParseIntPipe) id: number) {
    const user = await this.users.findById(id);
    if (user === null) {
      throw new NotFoundError('User not found.');
    }
    return this.resources.toUserJson(user);
  }

  /**
   * Creates a platform-admin account. The response carries the UserResource
   * only — never the password, and never a token pair, so the new admin has to
   * sign in through `POST /auth/login` like any other user.
   */
  @Post()
  @Message('Admin user created successfully.')
  async create(@Body() dto: CreateAdminUserDto) {
    const user = await this.users.create({
      name: dto.name,
      email: dto.email,
      phone: dto.phone ?? null,
      password: dto.password,
      role: Role.PlatformAdmin,
      status: dto.status ?? UserStatus.Active,
    });
    return this.resources.toUserJson(user);
  }

  /**
   * Admin password reset. Does not require the target's current password: this
   * endpoint IS the recovery path for an admin who has lost theirs. All of the
   * target's refresh families are revoked, so the old password cannot mint a new
   * session.
   */
  @Put(':id/password')
  @Message('Password updated successfully.')
  async changePassword(
    @CurrentUser() actor: JwtPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ChangeAdminPasswordDto,
  ) {
    const user = await this.requireUser(id);
    // Setting your own password to the value it already holds is almost always
    // an accident, and reporting success would hide it.
    if (user.id === actor.sub) {
      const matches = await this.users.verifyCredentials(user.email, dto.password);
      if (matches !== null) {
        throw new ValidationError('The given data was invalid.', {
          password: ['The new password must be different from the current one.'],
        });
      }
    }

    const updated = await this.users.setPassword(user, dto.password);
    await this.auth.revokeSessions(updated.id);
    return this.resources.toUserJson(updated);
  }

  /**
   * Enable/disable/suspend an admin. `AuthService.login` already refuses any
   * non-ACTIVE account, so this blocks future sign-ins.
   *
   * Self-demotion is rejected: an admin who suspends themselves can no longer
   * reach this controller to undo it.
   */
  @Put(':id/status')
  @Message('User status updated successfully.')
  async updateStatus(
    @CurrentUser() actor: JwtPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAdminUserStatusDto,
  ) {
    if (id === actor.sub && dto.status !== UserStatus.Active) {
      throw new ForbiddenError('You cannot suspend your own account.');
    }

    const user = await this.requireUser(id);
    const updated = await this.users.setStatus(user, dto.status);
    // An account leaving ACTIVE should not keep refreshing behind the scenes.
    if (dto.status !== UserStatus.Active) {
      await this.auth.revokeSessions(updated.id);
    }
    return this.resources.toUserJson(updated);
  }

  private async requireUser(id: number): Promise<User> {
    const user = await this.users.findById(id);
    if (user === null) {
      throw new NotFoundError('User not found.');
    }
    return user;
  }
}