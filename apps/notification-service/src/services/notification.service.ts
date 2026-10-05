import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Like, Repository } from 'typeorm';
import { Notification } from '../entities/notification.entity';

/**
 * Type prefix reserved for the platform-admin audience. Anything published
 * with it appears in the admin feed regardless of which admin received it.
 */
export const ADMIN_TYPE_PREFIX = 'admin.';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    @InjectRepository(Notification) private readonly notifications: Repository<Notification>,
  ) {}

  async create(input: {
    sourceKey?: string;
    userId: number;
    type: string;
    title: string;
    body: string;
    data?: Record<string, unknown>;
  }): Promise<Notification> {
    if (input.sourceKey) {
      await this.notifications.createQueryBuilder().insert().values({
        userId: input.userId, type: input.type, title: input.title, body: input.body,
        data: () => ':notificationData', sourceKey: input.sourceKey,
        isRead: false, readAt: null, sentAt: new Date(),
      }).setParameter('notificationData', input.data ? JSON.stringify(input.data) : null).orIgnore().execute();
      return this.notifications.findOneByOrFail({ sourceKey: input.sourceKey });
    }
    const notification = await this.notifications.save(
      this.notifications.create({
        userId: input.userId,
        type: input.type,
        title: input.title,
        body: input.body,
        data: input.data ?? null,
        isRead: false,
        readAt: null,
        sentAt: new Date(),
      }),
    );

    this.logger.log(`Notification #${notification.id} created for user #${input.userId}`);
    return notification;
  }

  async listForUser(userId: number, page: number, perPage: number): Promise<{ items: Notification[]; total: number }> {
    const [items, total] = await this.notifications.findAndCount({
      where: { userId },
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { items, total };
  }

  async findForUser(id: number, userId: number): Promise<Notification | null> {
    return this.notifications.findOne({ where: { id, userId } });
  }

  /**
   * Platform-wide feed for admins: every notification raised for the admin
   * audience, across all admin recipients.
   *
   * Scoped by the `admin.` type prefix rather than by a column, so the
   * audience is visible in the payload and a platform alert can never be
   * confused with a customer notification.
   */
  async listForAdmins(
    page: number,
    perPage: number,
  ): Promise<{ items: Notification[]; total: number; unread: number; byType: Array<{ type: string; count: number }> }> {
    const [items, total, unread, grouped] = await Promise.all([
      this.notifications.find({
        where: { type: Like(`${ADMIN_TYPE_PREFIX}%`) },
        order: { id: 'DESC' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.notifications.count({ where: { type: Like(`${ADMIN_TYPE_PREFIX}%`) } }),
      this.notifications.count({ where: { type: Like(`${ADMIN_TYPE_PREFIX}%`), isRead: false } }),
      this.notifications
        .createQueryBuilder('n')
        .select('n.type', 'type')
        .addSelect('COUNT(*)::int', 'count')
        .where('n.type LIKE :prefix', { prefix: `${ADMIN_TYPE_PREFIX}%` })
        .groupBy('n.type')
        .orderBy('count', 'DESC')
        .getRawMany<{ type: string; count: number }>(),
    ]);
    return { items, total, unread, byType: grouped };
  }

  /** Feed for every member of a store, so one store admin sees the store's alerts. */
  async listForUsers(
    userIds: number[],
    page: number,
    perPage: number,
  ): Promise<{ items: Notification[]; total: number; unread: number }> {
    if (userIds.length === 0) {
      return { items: [], total: 0, unread: 0 };
    }
    const [items, total, unread] = await Promise.all([
      this.notifications.find({
        where: { userId: In(userIds) },
        order: { id: 'DESC' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.notifications.count({ where: { userId: In(userIds) } }),
      this.notifications.count({ where: { userId: In(userIds), isRead: false } }),
    ]);
    return { items, total, unread };
  }

  async markAsRead(id: number, userId: number): Promise<Notification> {
    const notification = await this.notifications.findOne({ where: { id, userId } });
    if (!notification) throw new NotFoundException('Notification not found.');
    if (notification.isRead) return notification;
    notification.isRead = true;
    notification.readAt = new Date();
    return this.notifications.save(notification);
  }

  async markAllAsRead(userId: number): Promise<Notification[]> {
    return this.notifications.save(
      this.notifications.create(
        (
          await this.notifications.find({
            where: { userId, isRead: false },
            order: { id: 'ASC' },
          })
        ).map((n) => this.notifications.create({ ...n, isRead: true, readAt: new Date() })),
      ),
    );
  }

  async unreadCount(userId: number): Promise<number> {
    return this.notifications.count({ where: { userId, isRead: false } });
  }

  async health(): Promise<{ mode: string; pending: number }> {
    const pending = await this.notifications.count({ where: { sentAt: IsNull() } });
    const mode = process.env.FCM_SERVER_KEY ? 'fcm' : 'stub';
    return { mode, pending };
  }
}
