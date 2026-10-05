import { resolveTarget } from './gateway.routes';

describe('gateway routes', () => {
  const urls: Record<string, string> = {
    IDENTITY_SERVICE_URL: 'http://localhost:3001',
    MERCHANT_SERVICE_URL: 'http://localhost:3002',
    CATALOG_SERVICE_URL: 'http://localhost:3003',
    ORDER_SERVICE_URL: 'http://localhost:3004',
    DISPATCH_SERVICE_URL: 'http://localhost:3005',
    PAYMENT_SERVICE_URL: 'http://localhost:3006',
    NOTIFICATION_SERVICE_URL: 'http://localhost:3007',
  };

  beforeEach(() => {
    for (const [key, value] of Object.entries(urls)) {
      process.env[key] = value;
    }
  });

  afterEach(() => {
    for (const key of Object.keys(urls)) {
      delete process.env[key];
    }
  });

  it('routes public auth endpoints to identity', () => {
    expect(resolveTarget('/api/v1/auth/login')?.urlEnv).toBe('IDENTITY_SERVICE_URL');
    expect(resolveTarget('/api/v1/auth/register')?.urlEnv).toBe('IDENTITY_SERVICE_URL');
  });

  it('routes rider/register to identity, ahead of the rider catch-all', () => {
    expect(resolveTarget('/api/v1/rider/register')?.urlEnv).toBe('IDENTITY_SERVICE_URL');
  });

  it('routes the rider app to dispatch', () => {
    expect(resolveTarget('/api/v1/rider/offers/12/accept')?.urlEnv).toBe('DISPATCH_SERVICE_URL');
    expect(resolveTarget('/api/v1/rider/deliveries/4/complete')?.urlEnv).toBe('DISPATCH_SERVICE_URL');
    expect(resolveTarget('/api/v1/rider/earnings-summary')?.urlEnv).toBe('DISPATCH_SERVICE_URL');
  });

  it('routes public store/product browsing to merchant and catalog', () => {
    expect(resolveTarget('/api/v1/stores')?.urlEnv).toBe('MERCHANT_SERVICE_URL');
    expect(resolveTarget('/api/v1/stores/5/products')?.urlEnv).toBe('CATALOG_SERVICE_URL');
    expect(resolveTarget('/api/v1/stores/5/categories')?.urlEnv).toBe('CATALOG_SERVICE_URL');
    expect(resolveTarget('/api/v1/products')?.urlEnv).toBe('CATALOG_SERVICE_URL');
    expect(resolveTarget('/api/v1/products/8')?.urlEnv).toBe('CATALOG_SERVICE_URL');
  });

  it('routes store-admin segments to their owning services', () => {
    expect(resolveTarget('/api/v1/store/profile')?.urlEnv).toBe('MERCHANT_SERVICE_URL');
    expect(resolveTarget('/api/v1/store/categories')?.urlEnv).toBe('CATALOG_SERVICE_URL');
    expect(resolveTarget('/api/v1/store/products/3')?.urlEnv).toBe('CATALOG_SERVICE_URL');
    expect(resolveTarget('/api/v1/store/orders')?.urlEnv).toBe('ORDER_SERVICE_URL');
  });

  it('routes admin segments to their owning services', () => {
    expect(resolveTarget('/api/v1/admin/store-categories')?.urlEnv).toBe('MERCHANT_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/stores/1/categories')?.urlEnv).toBe('MERCHANT_SERVICE_URL');
    expect(resolveTarget('/api/v1/store-categories')?.urlEnv).toBe('MERCHANT_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/dashboard')?.urlEnv).toBe('DISPATCH_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/deliveries')?.urlEnv).toBe('DISPATCH_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/riders/1/suspend')?.urlEnv).toBe('DISPATCH_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/orders')?.urlEnv).toBe('ORDER_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/stores')?.urlEnv).toBe('MERCHANT_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/customers')?.urlEnv).toBe('IDENTITY_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/users')?.urlEnv).toBe('IDENTITY_SERVICE_URL');
    expect(resolveTarget('/api/v1/admin/users/1')?.urlEnv).toBe('IDENTITY_SERVICE_URL');
  });

  it('routes customer orders, notifications and payments', () => {
    expect(resolveTarget('/api/v1/orders')?.urlEnv).toBe('ORDER_SERVICE_URL');
    expect(resolveTarget('/api/v1/orders/42/cancel')?.urlEnv).toBe('ORDER_SERVICE_URL');
    expect(resolveTarget('/api/v1/notifications')?.urlEnv).toBe('NOTIFICATION_SERVICE_URL');
    expect(resolveTarget('/api/v1/payments')?.urlEnv).toBe('PAYMENT_SERVICE_URL');
  });

  it('returns null (404) for unmapped paths', () => {
    expect(resolveTarget('/api/v1/unmapped/thing')).toBeNull();
    expect(resolveTarget('/nope')).toBeNull();
  });

  it('returns null when the owning service URL is unset', () => {
    delete process.env.IDENTITY_SERVICE_URL;
    expect(resolveTarget('/api/v1/auth/login')).toBeNull();
  });

  it('matches the prefix exactly and as a path segment only', () => {
    expect(resolveTarget('/api/v1/orders')).not.toBeNull();
    // `/admin/orders` must not be swallowed by the plain `/orders` prefix.
    expect(resolveTarget('/api/v1/admin/orders')?.urlEnv).toBe('ORDER_SERVICE_URL');
  });
});
