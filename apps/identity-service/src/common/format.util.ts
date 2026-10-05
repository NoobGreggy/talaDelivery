/** Shared formatting helpers for identity-service (mirrors dispatch's util). */

export function toDate(value: Date | string | null | undefined): Date | null {
  if (value === null || value === undefined || value === '') return null;
  return value instanceof Date ? value : new Date(value);
}

export function toIso(value: Date | string | null | undefined): string | null {
  const parsed = toDate(value);
  return parsed ? parsed.toISOString() : null;
}

export function stringOrNull(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null;
  return String(value);
}

/** Collapses runs of whitespace and trims — normalizes free-text search terms. */
export function squish(value: string): string {
  return value.replace(/\s+/g, ' ').trim();
}