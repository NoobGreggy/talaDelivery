/** Exact browser origins only; native mobile clients do not require CORS. */
export function gatewayCorsOrigins(value = process.env.CORS_ORIGINS): string[] {
  const origins = value === undefined
    ? ['http://localhost:3000', 'http://localhost:4200', 'http://localhost:4300',
       'http://127.0.0.1:4200', 'http://127.0.0.1:4300']
    : value.split(',').map(origin => origin.trim()).filter(Boolean);
  for (const origin of origins) {
    const url = new URL(origin);
    if (!['http:', 'https:'].includes(url.protocol) || url.origin !== origin) {
      throw new Error('CORS_ORIGINS must contain comma-separated HTTP(S) origins without paths.');
    }
  }
  return [...new Set(origins)];
}
