import { Injectable, Logger } from '@nestjs/common';
import {
  EventType,
  EventWorkerManager,
  QueueName,
  type RealtimeEmitPayload,
} from '@taladelivery/events';
import { RealtimeGateway } from '../realtime.gateway';

/**
 * Broadcasts domain events to Socket.IO rooms on behalf of other services.
 *
 * realtime-service owns `realtime-feed`; publishers state the audience as
 * concrete rooms so this consumer never has to decide who may see what.
 * Room authorization still happens at subscribe time in
 * `RealtimeGateway.canSubscribe`.
 */
@Injectable()
export class RealtimeFeedConsumer {
  private readonly logger = new Logger(RealtimeFeedConsumer.name);

  constructor(
    private readonly workerManager: EventWorkerManager,
    private readonly gateway: RealtimeGateway,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.workerManager.on(
      QueueName.RealtimeFeed,
      async (data: unknown) => {
        const payload = data as RealtimeEmitPayload;
        if (!Array.isArray(payload?.rooms) || payload.rooms.length === 0) {
          this.logger.warn(`realtime.emit with no rooms: ${JSON.stringify(payload)}`);
          return;
        }
        for (const room of payload.rooms) {
          this.gateway.emitToRoom(room, payload.event, payload.data);
        }
        this.logger.log(
          `Emitted ${payload.event} to ${payload.rooms.length} room(s): ${payload.rooms.join(', ')}`,
        );
      },
      { eventTypes: [EventType.RealtimeEmit] },
    );
    this.logger.log('Realtime feed consumer registered');
  }
}
