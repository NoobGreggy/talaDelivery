/** Optional deployment-local browser config, loaded before Angular starts. */
export function localMapboxToken(): string {
  const token = (globalThis as typeof globalThis & {
    TALA_MAPBOX_ACCESS_TOKEN?: unknown;
  }).TALA_MAPBOX_ACCESS_TOKEN;
  // Browser maps must never use a secret (sk.) Mapbox token.
  return typeof token === 'string' && token.startsWith('pk.') ? token : '';
}
