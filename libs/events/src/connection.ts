import type { ConnectionOptions } from 'bullmq';

export interface RedisEnv {
  host: string;
  port: number;
  password?: string;
  db?: number;
}

/** Builds BullMQ-compatible Redis connection options from env values. */
export function redisConnectionFrom(env: RedisEnv): ConnectionOptions {
  return {
    host: env.host,
    port: env.port,
    password: env.password ? env.password : undefined,
    db: env.db ?? 0,
  };
}