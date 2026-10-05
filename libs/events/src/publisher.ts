import { Inject, Injectable, Logger } from '@nestjs/common';
import { Queue, type ConnectionOptions } from 'bullmq';
import type { EventEnvelope } from './event.envelope';
import { randomUuid } from './event.envelope';
import { describeRedisError } from './redis-error';

export const EVENTS_CONNECTION = Symbol('EVENTS_CONNECTION');
export const EVENTS_PREFIX = Symbol('EVENTS_PREFIX');
export const EVENTS_PUBLISH_TIMEOUT_MS = Symbol('EVENTS_PUBLISH_TIMEOUT_MS');
export const EVENTS_FAIL_SOFT = Symbol('EVENTS_FAIL_SOFT');

/** Default ceiling for a single `queue.add` before we give up on it. */
export const DEFAULT_PUBLISH_TIMEOUT_MS = 2000;

/**
 * Thin wrapper over BullMQ queues used for publishing domain events.
 * A queue can be reused for multiple event types (see QueueName).
 */
@Injectable()
export class EventPublisher {
  private readonly logger = new Logger(EventPublisher.name);
  private readonly queues = new Map<string, Queue>();

  constructor(
    @Inject(EVENTS_CONNECTION) private readonly connection: ConnectionOptions,
    @Inject(EVENTS_PREFIX) private readonly prefix: string,
    @Inject(EVENTS_PUBLISH_TIMEOUT_MS) private readonly publishTimeoutMs: number,
    @Inject(EVENTS_FAIL_SOFT) private readonly failSoft: boolean,
  ) {}

  queue(name: string): Queue {
    let queue = this.queues.get(name);
    if (!queue) {
      queue = new Queue(name, {
        // Queues (unlike Workers) must not buffer commands while offline —
        // otherwise `add` resolves only when Redis finally reconnects, which
        // silently hangs the request that triggered the publish.
        connection: { ...this.connection, maxRetriesPerRequest: 1 } as ConnectionOptions,
        prefix: this.prefix,
      });
      // Without a listener ioredis logs an unhandled 'error' event per retry.
      queue.on('error', (err: Error) => {
        this.logger.warn(`queue ${name} redis error: ${err.message}`);
      });
      this.queues.set(name, queue);
    }
    return queue;
  }

  /**
   * Enqueue an arbitrary job on a queue, bounded by `publishTimeoutMs`.
   *
   * When Redis is unavailable the enqueue is abandoned after the timeout
   * instead of hanging the caller. `failSoft` (on by default outside
   * production) downgrades that to a warning so an unavailable broker
   * cannot take down unrelated business flows; set EVENTS_FAIL_SOFT=false
   * to make it throw instead.
   *
   * @returns true when the job was enqueued, false when it was dropped.
   */
  async addJob(
    queueName: string,
    jobName: string,
    payload: object,
    opts: { jobId?: string; delayMs?: number } = {},
  ): Promise<boolean> {
    try {
      await this.withTimeout(
        this.queue(queueName).add(jobName, payload, {
          jobId: opts.jobId,
          delay: opts.delayMs,
          removeOnComplete: 1000,
          removeOnFail: 5000,
        }),
        this.publishTimeoutMs,
        queueName,
      );
      return true;
    } catch (err) {
      if (!this.failSoft) {
        throw err;
      }
      this.logger.warn(
        `dropped ${jobName} on ${queueName} — broker unavailable after ` +
          `${this.publishTimeoutMs}ms: ${describeRedisError(err)}`,
      );
      return false;
    }
  }

  /**
   * Publish an envelope. Uses jobId = eventId so BullMQ deduplicates
   * identical events; consumers still run an idempotency check.
   */
  async publish(queueName: string, envelope: EventEnvelope<unknown>): Promise<void> {
    const enqueued = await this.addJob(queueName, 'event', envelope as object, {
      jobId: envelope.eventId,
    });
    if (enqueued) {
      this.logger.debug(
        `published ${envelope.eventType} id=${envelope.eventId} to ${queueName}`,
      );
    }
  }

  private withTimeout<T>(work: Promise<T>, ms: number, queueName: string): Promise<T> {
    if (!(ms > 0)) {
      return work;
    }
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`publish to ${queueName} timed out after ${ms}ms`));
      }, ms);
      // Do not hold the event loop open just for the timeout.
      timer.unref?.();
      work.then(
        (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        (err: Error) => {
          clearTimeout(timer);
          reject(err);
        },
      );
    });
  }

  /** Convenience: build envelope with a correlation id and publish. */
  async publishEvent<T extends object>(
    queueName: string,
    eventType: string,
    data: T,
    correlationId?: string,
  ): Promise<EventEnvelope<T>> {
    const envelope = {
      eventId: randomUuid(),
      eventType,
      eventVersion: 1,
      occurredAt: new Date().toISOString(),
      correlationId: correlationId ?? randomUuid(),
      data,
    } satisfies EventEnvelope<T>;
    await this.publish(queueName, envelope as EventEnvelope<unknown>);
    return envelope;
  }

  async close(): Promise<void> {
    await Promise.all([...this.queues.values()].map((q) => q.close()));
    this.queues.clear();
  }
}