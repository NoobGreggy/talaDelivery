import { DynamicModule, Global, Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import type { ConnectionOptions } from 'bullmq';
import {
  DEFAULT_PUBLISH_TIMEOUT_MS,
  EVENTS_CONNECTION,
  EVENTS_FAIL_SOFT,
  EVENTS_PREFIX,
  EVENTS_PUBLISH_TIMEOUT_MS,
  EventPublisher,
} from './publisher';
import {
  EVENTS_DEDUPE_TTL_SECONDS,
  EVENTS_REDIS_CLIENT,
  EventWorkerManager,
} from './worker-manager';
import { redisConnectionFrom } from './connection';
import { describeRedisError } from './redis-error';

export interface EventsModuleOptions {
  /** Prefix for BullMQ queues (default: env BULLMQ_PREFIX or "bull"). */
  prefix?: string;
  /** Dedupe TTL in seconds for consumed events (default: 86400 = 24h). */
  dedupeTtlSeconds?: number;
  /** Ceiling for a single enqueue before it is abandoned (default 2000ms). */
  publishTimeoutMs?: number;
  /**
   * When true (default outside production) an unreachable broker logs a
   * warning instead of failing the calling business flow.
   */
  failSoft?: boolean;
}

/**
 * Provides Redis connection, EventPublisher and EventWorkerManager.
 * Reads REDIS_* values from the app env configuration.
 */
@Global()
@Module({})
export class EventsModule {
  static forRoot(options: EventsModuleOptions = {}): DynamicModule {
    return {
      module: EventsModule,
      global: true,
      providers: [
        {
          provide: EVENTS_PREFIX,
          useFactory: (config: ConfigService): string =>
            options.prefix ?? config.get<string>('BULLMQ_PREFIX') ?? 'bull',
          inject: [ConfigService],
        },
        {
          provide: EVENTS_CONNECTION,
          useFactory: (config: ConfigService): ConnectionOptions =>
            redisConnectionFrom({
              host: config.get<string>('REDIS_HOST', 'localhost'),
              port: config.get<number>('REDIS_PORT', 6379),
              password: config.get<string>('REDIS_PASSWORD') || undefined,
              db: config.get<number>('REDIS_DB', 0),
            }),
          inject: [ConfigService],
        },
        {
          provide: EVENTS_REDIS_CLIENT,
          useFactory: (config: ConfigService): Redis => {
            const client = new Redis({
              host: config.get<string>('REDIS_HOST', 'localhost'),
              port: config.get<number>('REDIS_PORT', 6379),
              password: config.get<string>('REDIS_PASSWORD') || undefined,
              db: config.get<number>('REDIS_DB', 0),
              lazyConnect: true,
              maxRetriesPerRequest: null,
            });
            // ioredis emits 'error' on every failed reconnect attempt; without a
            // listener each one is logged as an unhandled error event.
            client.on('error', (err: Error) => {
              Logger.error(
                `events redis unavailable: ${describeRedisError(err)}`,
                'EventsModule',
              );
            });
            return client;
          },
          inject: [ConfigService],
        },
        {
          provide: EVENTS_PUBLISH_TIMEOUT_MS,
          useFactory: (config: ConfigService): number =>
            options.publishTimeoutMs ??
            config.get<number>('EVENTS_PUBLISH_TIMEOUT_MS') ??
            DEFAULT_PUBLISH_TIMEOUT_MS,
          inject: [ConfigService],
        },
        {
          provide: EVENTS_FAIL_SOFT,
          useFactory: (config: ConfigService): boolean =>
            options.failSoft ??
            (config.get<string>('EVENTS_FAIL_SOFT') !== 'false' &&
              config.get<string>('NODE_ENV') !== 'production'),
          inject: [ConfigService],
        },
        {
          provide: EVENTS_DEDUPE_TTL_SECONDS,
          useValue: options.dedupeTtlSeconds ?? 86400,
        },
        EventPublisher,
        EventWorkerManager,
      ],
      exports: [
        EVENTS_CONNECTION,
        EVENTS_REDIS_CLIENT,
        EVENTS_PREFIX,
        EVENTS_PUBLISH_TIMEOUT_MS,
        EVENTS_FAIL_SOFT,
        EventPublisher,
        EventWorkerManager,
      ],
    };
  }
}

export {
  DEFAULT_PUBLISH_TIMEOUT_MS,
  EVENTS_CONNECTION,
  EVENTS_PREFIX,
  EVENTS_PUBLISH_TIMEOUT_MS,
  EVENTS_FAIL_SOFT,
  EventPublisher,
} from './publisher';
export {
  EVENTS_DEDUPE_TTL_SECONDS,
  EVENTS_REDIS_CLIENT,
  EventWorkerManager,
  type EventHandler,
  type EventDispatchContext,
} from './worker-manager';
export type { EventEnvelope } from './event.envelope';
export { buildEnvelope, randomUuid } from './event.envelope';
export { EventType, QueueName, IdempotencyKeyPrefix, RedisKey } from './event.names';
export { redisConnectionFrom, type RedisEnv } from './connection';