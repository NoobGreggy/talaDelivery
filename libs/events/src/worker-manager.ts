import {
  Inject,
  Injectable,
  Logger,
  type OnApplicationShutdown,
  type OnModuleInit,
} from '@nestjs/common';
import { Job, Worker, type ConnectionOptions } from 'bullmq';
import type Redis from 'ioredis';
import type { EventEnvelope } from './event.envelope';
import { EVENTS_CONNECTION, EVENTS_PREFIX } from './publisher';
import { describeRedisError } from './redis-error';

export const EVENTS_REDIS_CLIENT = Symbol('EVENTS_REDIS_CLIENT');
export const EVENTS_DEDUPE_TTL_SECONDS = Symbol('EVENTS_DEDUPE_TTL_SECONDS');

export interface EventDispatchContext {
  correlationId: string;
}

export type EventHandler<D = unknown> = (
  data: D,
  envelope: EventEnvelope<D>,
  context: EventDispatchContext,
) => Promise<void> | void;

interface Registration {
  queueName: string;
  eventTypes: ReadonlySet<string>;
  handler: EventHandler;
}

/**
 * Manages BullMQ Worker instances for event consumption.
 * - Decodes the standard envelope.
 * - Dispatches to the first registration on the queue that accepts the
 *   eventType, so one process can host several handlers per queue.
 * - Runs an idempotency check (Redis SET NX on the eventId) so duplicate
 *   jobs / redeliveries are harmless.
 * - Bounded retries with backoff, failed jobs are observable.
 *
 * IMPORTANT — one consumer process per queue.
 *
 * BullMQ gives a claimed job to exactly one worker. This manager therefore
 * *cannot* be used to let two services share a queue and filter by
 * `eventTypes`: whichever process claims a job it does not handle destroys
 * it. Publishers must fan out to a separate queue per subscribing service.
 * See nestjs_api.md §20.14.
 */
@Injectable()
export class EventWorkerManager implements OnModuleInit, OnApplicationShutdown {
  private readonly registrations = new Map<string, Registration[]>();
  private readonly workerByQueue = new Map<string, Worker>();
  private readonly workers: Worker[] = [];
  private readonly logger = new Logger(EventWorkerManager.name);
  private initialized = false;

  constructor(
    @Inject(EVENTS_CONNECTION) private readonly connection: ConnectionOptions,
    @Inject(EVENTS_PREFIX) private readonly prefix: string,
    @Inject(EVENTS_REDIS_CLIENT) private readonly redis: Redis,
    @Inject(EVENTS_DEDUPE_TTL_SECONDS) private readonly dedupeTtl: number,
  ) {}

  /**
   * Register a handler for a queue, optionally filtering by eventType.
   * Multiple registrations for the same queue are all retained; a job is
   * dispatched to the first one whose filter accepts its eventType.
   */
  on(
    queueName: string,
    handler: EventHandler,
    opts?: { eventTypes?: readonly string[]; concurrency?: number; attempts?: number; backoffMs?: number },
  ): this {
    const existing = this.registrations.get(queueName) ?? [];
    existing.push({
      queueName,
      eventTypes: new Set(opts?.eventTypes),
      handler,
    });
    this.registrations.set(queueName, existing);
    // A worker may already be booted (when registration happens from another
    // provider's onModuleInit); spin it up immediately so nothing is missed.
    if (this.initialized) {
      this.ensureWorker(queueName);
    }
    return this;
  }

  onModuleInit(): void {
    this.initialized = true;
    for (const queueName of [...this.registrations.keys()]) {
      this.ensureWorker(queueName);
    }
  }

  private ensureWorker(queueName: string): void {
    if (this.workerByQueue.has(queueName)) {
      return;
    }
    if (!this.registrations.has(queueName)) {
      return;
    }
    const worker = new Worker(
      queueName,
      async (job: Job) => this.process(queueName, job),
      {
        connection: this.connection,
        prefix: this.prefix,
        concurrency: 5,
      },
    );
    this.workerByQueue.set(queueName, worker);
    this.workers.push(worker);
    // Workers retry forever by design; log each failure once instead of
    // letting ioredis report an unhandled 'error' event per attempt.
    worker.on('error', (err: Error) => {
      Logger.error(
        `worker ${queueName} redis error: ${describeRedisError(err)}`,
        EventWorkerManager.name,
      );
    });
  }

  /** First registration on this queue that accepts the event, if any. */
  private resolve(queueName: string, eventType: string): Registration | undefined {
    const candidates = this.registrations.get(queueName) ?? [];
    return candidates.find(
      (registration) =>
        registration.eventTypes.size === 0 || registration.eventTypes.has(eventType),
    );
  }

  private async process(queueName: string, job: Job): Promise<void> {
    const envelope = job.data as EventEnvelope<unknown>;
    if (!envelope || typeof envelope !== 'object' || !envelope.eventType) {
      return; // malformed payload - silently skip (already observable via failed job)
    }

    const registration = this.resolve(queueName, envelope.eventType);
    if (registration === undefined) {
      // No handler in this process wants this event. That is only safe when
      // this process is the queue's sole consumer; otherwise the event is
      // being destroyed by a competing worker. Make that visible.
      this.logger.warn(
        `no handler for ${envelope.eventType} on ${queueName}; job #${job.id} discarded. ` +
          'If another service also consumes this queue, that event is being lost.',
      );
      return;
    }

    const dedupeKey = `taladelivery:evt:${envelope.eventId}`;
    const claimed = await this.redis.set(dedupeKey, '1', 'EX', this.dedupeTtl, 'NX');
    if (claimed !== 'OK') {
      // Already processed - idempotent consumer.
      return;
    }

    await registration.handler(envelope.data, envelope, {
      correlationId: envelope.correlationId,
    });
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.all(this.workers.map((worker) => worker.close()));
    this.workers.length = 0;
  }
}