import { fromMinor, toMinor } from '@taladelivery/common';

/**
 * Two-decimal decimal-string helper for money (mirrors Laravel decimal:2 casting).
 * Accepts floats produced by pricing math and normalizes away float noise.
 */
export function moneyString(value: number | string): string {
  if (typeof value === 'string') return value;
  return fromMinor(toMinor(value));
}

export function stringOrNull(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null;
  return String(value);
}

export function toIso(value: Date | string | null | undefined): string | null {
  if (value === null || value === undefined || value === '') return null;
  const parsed = value instanceof Date ? value : new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}