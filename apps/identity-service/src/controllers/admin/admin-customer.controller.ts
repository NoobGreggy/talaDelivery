import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  AppKeyGuard,
  JwtAuthGuard,
  Roles,
  RolesGuard,
} from '@taladelivery/auth';
import { Message, PaginatedResult, requestContext, resolvePagination } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { UserService } from '../../services/user.service';
import { UserResourcesService } from '../../services/user-resources.service';
import { squish } from '../../common/format.util';

/**
 * Admin customer listing (mirrors Laravel AdminCustomerController@index).
 *
 * Guards: X-App-Key + JWT + platform_admin. Identity owns the users table, so
 * this list never cross-DB joins — the Laravel UserResource's `rider` /
 * `orders_count` / `total_spent` stay null/zero here because those facts live
 * in dispatch- and order-service. The internal snapshot contract (§1.1) keeps
 * the same boundary.
 */
@Controller('admin/customers')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminCustomerController {
  constructor(
    private readonly users: UserService,
    private readonly resources: UserResourcesService,
  ) {}

  @Get()
  @Message('Customers retrieved.')
  async index(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const term = search === undefined ? undefined : squish(search);

    const { items, total } = await this.users.listByRole(Role.Customer, {
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
}