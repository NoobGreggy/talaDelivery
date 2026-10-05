import { fromMinor, toMinor } from '@taladelivery/common';

/**
 * Two-decimal decimal-string helper for money (mirrors Laravel decimal:2
 * casting). All payment math runs in integer minor units (`toMinor`/`fromMinor`).
 */
export function moneyString(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === '') return '0.00';
  if (typeof value === 'string') return value;
  return fromMinor(toMinor(value));
}

export function toIso(value: Date | string | null | undefined): string | null {
  if (value === null || value === undefined || value === '') return null;
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}