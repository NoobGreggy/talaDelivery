import { Injectable, Logger } from '@nestjs/common';
import { EventPublisher, EventWorkerManager, EventType, QueueName } from '@taladelivery/events';
import { NotificationService } from '../services/notification.service';

interface NotificationCreatePayload {
  sourceKey?: string;
  userId: number;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

@Injectable()
export class NotificationConsumer {
  private readonly logger = new Logger(NotificationConsumer.name);

  constructor(
    private readonly workerManager: EventWorkerManager,
    private readonly notifications: NotificationService,
    private readonly events: EventPublisher,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.workerManager.on(
      QueueName.NotificationJobs,
      // The first argument is already `envelope.data`. Reading `event.data`
      // here picked up the payload's inner `data` blob instead, so `userId`
      // arrived as undefined and every insert violated the not-null
      // constraint on `notifications.user_id`.
      async (data: unknown, envelope: { eventId: string; correlationId: string }) => {
        const input = data as NotificationCreatePayload;
        const notification = await this.notifications.create({ ...input,
          sourceKey: input.sourceKey ?? `notification-event-${envelope.eventId}` });
        // Emit only after persistence: the browser can now safely refresh its
        // feed without racing the new order's notification insert.
        await this.events.publishEvent(QueueName.RealtimeFeed, EventType.RealtimeEmit, {
          rooms: [`user:${notification.userId}`], event: 'notification.created',
          data: { id: notification.id, type: notification.type, title: notification.title,
            body: notification.body, data: notification.data, is_read: notification.isRead,
            created_at: notification.createdAt.toISOString() },
        }, envelope.correlationId);
      },
      { eventTypes: [EventType.NotificationCreate] },
    );
    this.logger.log('Notification consumer registered');
  }
}
