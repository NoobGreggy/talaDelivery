import {
  Controller,
  ForbiddenException,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  Roles,
  RolesGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import {
  Message,
  PaginatedResult,
  requestContext,
  ServiceClientFactory,
  type ServiceClient,
} from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { Notification } from '../entities/notification.entity';
import { NotificationService } from '../services/notification.service';

interface StoreSnapshot {
  id: number;
  name?: string;
}

/**
 * Role-scoped notification feeds.
 *
 * The per-user feed (`/notifications`) already works for any authenticated
 * caller. These add the cross-user views an admin or store console needs.
 * Scope is always derived from the token — never from a query parameter — so
 * a store admin cannot read another store's alerts by changing the URL.
 */
@Controller()
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
export class ScopedNotificationsController {
  private readonly merchant: ServiceClient;

  constructor(
    private readonly notifications: NotificationService,
    factory: ServiceClientFactory,
  ) {
    this.merchant = factory.create('MERCHANT_SERVICE_URL');
  }

  @Get('admin/notifications')
  @Roles(Role.PlatformAdmin)
  @Message('Platform notifications retrieved.')
  async adminFeed(
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePaging(page, perPage);
    const { items, total, unread, byType } = await this.notifications.listForAdmins(p, pp);
    return new PaginatedResult(items.map((n) => this.toJson(n)), {
      currentPage: p,
      lastPage: Math.max(1, Math.ceil(total / pp)),
      perPage: pp,
      total,
      path: requestContext().path,
      extra: { unread, by_type: byType },
    });
  }

  @Get('merchant/notifications')
  @Roles(Role.StoreAdmin)
  @Message('Store notifications retrieved.')
  async merchantFeed(
    @CurrentUser() user: JwtPayload,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const store = await this.resolveStore(user.sub);
    if (store === null) {
      throw new ForbiddenException('You are not a member of any store.');
    }
    const { page: p, perPage: pp } = resolvePaging(page, perPage);
    const { items, total, unread } = await this.notifications.listForUsers(
      await this.storeMemberIds(store.id),
      p,
      pp,
    );
    return new PaginatedResult(items.map((n) => this.toJson(n)), {
      currentPage: p,
      lastPage: Math.max(1, Math.ceil(total / pp)),
      perPage: pp,
      total,
      path: requestContext().path,
      extra: { unread, store: { id: store.id, name: store.name ?? null } },
    });
  }

  /**
   * The caller's first store. `by-user` returns an array of snapshots (a user
   * may belong to more than one store); the feed is scoped to the first, and
   * the query parameter is deliberately not accepted so a store admin cannot
   * widen their own scope.
   */
  private async resolveStore(userId: number): Promise<StoreSnapshot | null> {
    try {
      const stores = await this.merchant.get<StoreSnapshot[]>(
        `/internal/stores/by-user/${userId}`,
      );
      return Array.isArray(stores) && stores.length > 0 ? stores[0] : null;
    } catch {
      return null;
    }
  }

  private async storeMemberIds(storeId: number): Promise<number[]> {
    try {
      const result = await this.merchant.get<{ userIds: number[] }>(
        `/internal/stores/${storeId}/store-users`,
      );
      return result?.userIds ?? [];
    } catch {
      return [];
    }
  }

  private toJson(n: Notification) {
    return {
      id: n.id,
      user_id: n.userId,
      type: n.type,
      title: n.title,
      body: n.body,
      data: n.data,
      is_read: n.isRead,
      read_at: n.readAt,
      sent_at: n.sentAt,
      created_at: n.createdAt,
    };
  }
}

function resolvePaging(page?: number, perPage?: number): { page: number; perPage: number } {
  const p = Number.isFinite(Number(page)) && Number(page) > 0 ? Number(page) : 1;
  const requested = Number.isFinite(Number(perPage)) ? Number(perPage) : 15;
  return { page: p, perPage: Math.min(Math.max(requested, 1), 100) };
}
