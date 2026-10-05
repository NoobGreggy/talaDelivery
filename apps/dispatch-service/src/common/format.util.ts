import { fromMinor, toMinor } from '@taladelivery/common';

/**
 * Two-decimal decimal-string helper for money (mirrors Laravel decimal:2 casting).
 * Accepts floats produced by pricing math and normalizes away float noise.
 */
export function moneyString(value: number | string): string {
  if (typeof value === 'string') return value;
  return fromMinor(toMinor(value));
}

/** distance_km style two-decimal string. */
export function twoDecimal(value: number | string): string {
  if (typeof value === 'string') return value;
  return fromMinor(toMinor(value));
}

/** Coordinate decimal string (precision 10/7 like Laravel). */
export function coordinateString(value: number | null | undefined): string | null {
  if (value === null || value === undefined) return null;
  return Number(value).toFixed(6);
}

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