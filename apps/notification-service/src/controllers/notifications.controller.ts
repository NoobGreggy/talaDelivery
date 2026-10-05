import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AppKeyGuard, CurrentUser, JwtAuthGuard, type JwtPayload } from '@taladelivery/auth';
import {
  Message,
  PaginatedResult,
  requestContext,
  resolvePagination,
} from '@taladelivery/common';
import { Notification } from '../entities/notification.entity';
import { NotificationService } from '../services/notification.service';

/**
 * Customer-facing notification feed (contracts §11).
 *
 * Scoped to the authenticated user: a notification id belonging to someone
 * else is reported as not found rather than forbidden, so the endpoint cannot
 * be used to probe which ids exist.
 */
@Controller('notifications')
@UseGuards(AppKeyGuard, JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationService) {}

  @Get()
  @Message('Notifications retrieved.')
  async index(
    @CurrentUser() user: JwtPayload,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const [{ items, total }, unread] = await Promise.all([
      this.notifications.listForUser(user.sub, p, pp), this.notifications.unreadCount(user.sub),
    ]);
    return new PaginatedResult(
      items.map((n) => this.toJson(n)),
      {
        currentPage: p,
        lastPage: Math.max(1, Math.ceil(total / pp)),
        perPage: pp,
        total,
        path: requestContext().path,
        extra: { unread },
      },
    );
  }

  @Post(':id/read')
  @Message('Notification marked as read.')
  async markRead(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseIntPipe) id: number,
  ) {
    const existing = await this.notifications.findForUser(id, user.sub);
    if (!existing) throw new NotFoundException('Notification not found.');
    const updated = await this.notifications.markAsRead(id, user.sub);
    return this.toJson(updated);
  }

  @Post('read-all')
  @Message('All notifications marked as read.')
  async markAllRead(@CurrentUser() user: JwtPayload) {
    const updated = await this.notifications.markAllAsRead(user.sub);
    return { updated: updated.length };
  }

  private toJson(n: Notification) {
    return {
      id: n.id,
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
