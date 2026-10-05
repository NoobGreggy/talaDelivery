/**
 * Integer (minor-unit) money helpers.
 *
 * The NestJS standard (§20.9) forbids floating point for money. All monetary
 * calculations happen in centavos (integer). Persistence/API use decimal
 * strings exactly like Laravel's decimal:2 casts ("200.00").
 */
export function toMinor(value: string | number): number {
  if (typeof value === 'number') {
    return Math.round(value * 100);
  }
  const normalized = value.trim();
  if (normalized === '') return 0;
  const numeric = Number.parseFloat(normalized);
  if (Number.isNaN(numeric)) return 0;
  return Math.round(numeric * 100);
}

/** min(n): 200.00, 100.5 -> "100.50", 0 -> "0.00" */
export function fromMinor(minor: number): string {
  const negative = minor < 0;
  const absolute = Math.abs(minor);
  const whole = Math.floor(absolute / 100);
  const cents = Math.floor(absolute % 100);
  const sign = negative ? '-' : '';
  return `${sign}${whole}.${String(cents).padStart(2, '0')}`;
}

export function addMinor(...values: number[]): number {
  return values.reduce((sum, value) => sum + value, 0);
}

export function roundMinorToTwo(major: number): number {
  return Math.round(major * 100);
}