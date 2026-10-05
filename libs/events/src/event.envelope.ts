/**
 * Standard event envelope (nestjs_api.md §20.12).
 * Identical shape used by every service for every published event.
 */
export interface EventEnvelope<T = unknown> {
  /** Unique event id (uuid). */
  eventId: string;
  /** past-tense dotted event name, e.g. "order.created". */
  eventType: string;
  eventVersion: number;
  /** ISO-8601 UTC timestamp of when the fact occurred. */
  occurredAt: string;
  /** Trace/correlation id propagated from the originating request. */
  correlationId: string;
  data: T;
}

export interface EventHandlerContext {
  correlationId: string;
}

/**
 * Builds a standard envelope with sensible defaults.
 * Kept dependency-free so unit tests can call it easily.
 */
export function buildEnvelope<T>(
  eventType: string,
  data: T,
  correlationId?: string,
  now: Date = new Date(),
): EventEnvelope<T> {
  return {
    eventId: randomUuid(),
    eventType,
    eventVersion: 1,
    occurredAt: now.toISOString(),
    correlationId: correlationId ?? randomUuid(),
    data,
  };
}

export function randomUuid(): string {
  // crypto.randomUUID is available on Node >= 16.7
  return globalThis.crypto.randomUUID();
}