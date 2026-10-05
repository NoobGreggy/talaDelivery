/**
 * ioredis surfaces connection failures as a bare `Error` with an empty
 * message plus a `code`, and BullMQ can wrap them in an AggregateError.
 * Fall back through those so log lines say something actionable.
 */
export function describeRedisError(err: unknown): string {
  if (err instanceof AggregateError && err.errors.length > 0) {
    return err.errors.map((inner) => describeRedisError(inner)).join('; ');
  }
  const error = err as { message?: string; code?: string; name?: string };
  if (error?.message) {
    return error.message;
  }
  return error?.code ?? error?.name ?? 'unknown error';
}
