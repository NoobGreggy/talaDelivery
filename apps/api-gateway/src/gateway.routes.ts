/**
 * Gateway routing table (internal-contracts.md §5).
 *
 * The gateway is a thin prefix-based proxy: it forwards the full request path
 * (including `/api/v1`) to the owning service's port, injects `X-App-Key`, and
 * forwards `x-user-*` / `x-correlation-id` / `x-request-id` / `x-store-id`
 * headers. It never inspects or produces business data.
 *
 * Rules are matched in order (most specific prefixes first).
 */
export interface GatewayRoute {
  /** URL prefix (including `/api/v1`) owned by the target service. */
  prefix: string;
  /** Environment variable holding the target service base URL. */
  urlEnv:
    | 'IDENTITY_SERVICE_URL'
    | 'MERCHANT_SERVICE_URL'
    | 'CATALOG_SERVICE_URL'
    | 'ORDER_SERVICE_URL'
    | 'DISPATCH_SERVICE_URL'
    | 'PAYMENT_SERVICE_URL'
    | 'NOTIFICATION_SERVICE_URL';
  /** Human-readable description (used in logs/tests only). */
  target: string;
}

export const GATEWAY_ROUTES: GatewayRoute[] = [
  // Identity service — auth + customer addresses + rider registration.
  { prefix: '/api/v1/auth', urlEnv: 'IDENTITY_SERVICE_URL', target: 'identity' },
  // Must precede the `/api/v1/rider` catch-all: rider registration is identity-owned.
  { prefix: '/api/v1/rider/register', urlEnv: 'IDENTITY_SERVICE_URL', target: 'identity' },
  { prefix: '/api/v1/addresses', urlEnv: 'IDENTITY_SERVICE_URL', target: 'identity' },
  { prefix: '/api/v1/admin/customers', urlEnv: 'IDENTITY_SERVICE_URL', target: 'identity' },
  // Platform-admin account provisioning; identity owns the users table.
  { prefix: '/api/v1/admin/users', urlEnv: 'IDENTITY_SERVICE_URL', target: 'identity' },

  // Merchant service — store browsing (public), store profile, admin stores.
  { prefix: '/api/v1/stores', urlEnv: 'MERCHANT_SERVICE_URL', target: 'merchant' },
  { prefix: '/api/v1/store/profile', urlEnv: 'MERCHANT_SERVICE_URL', target: 'merchant' },
  { prefix: '/api/v1/admin/stores', urlEnv: 'MERCHANT_SERVICE_URL', target: 'merchant' },
  { prefix: '/api/v1/admin/store-categories', urlEnv: 'MERCHANT_SERVICE_URL', target: 'merchant' },
  { prefix: '/api/v1/store-categories', urlEnv: 'MERCHANT_SERVICE_URL', target: 'merchant' },

  // Catalog service — products (public), store-admin categories/products.
  { prefix: '/api/v1/products', urlEnv: 'CATALOG_SERVICE_URL', target: 'catalog' },
  { prefix: '/api/v1/store/categories', urlEnv: 'CATALOG_SERVICE_URL', target: 'catalog' },
  { prefix: '/api/v1/store/products', urlEnv: 'CATALOG_SERVICE_URL', target: 'catalog' },

  // Order service — customer orders + store-admin/admin orders.
  { prefix: '/api/v1/store/orders', urlEnv: 'ORDER_SERVICE_URL', target: 'order' },
  { prefix: '/api/v1/orders', urlEnv: 'ORDER_SERVICE_URL', target: 'order' },
  { prefix: '/api/v1/admin/orders', urlEnv: 'ORDER_SERVICE_URL', target: 'order' },

  // Dispatch service — rider app + admin platform operations.
  { prefix: '/api/v1/rider', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },
  { prefix: '/api/v1/admin/dashboard', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },
  { prefix: '/api/v1/admin/settings', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },
  { prefix: '/api/v1/admin/delivery-zones', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },
  { prefix: '/api/v1/admin/place-boundaries', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },
  { prefix: '/api/v1/admin/deliveries', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },
  { prefix: '/api/v1/admin/riders', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },

  // Notification service — user-facing notifications.
  { prefix: '/api/v1/notifications', urlEnv: 'NOTIFICATION_SERVICE_URL', target: 'notification' },
  // Role-scoped notification feeds. These must precede the `/api/v1/admin/*`
  // and `/api/v1/merchant/*` rules below: the admin feed is notification-owned
  // even though it sits under `/admin`, and the merchant feed likewise.
  { prefix: '/api/v1/admin/notifications', urlEnv: 'NOTIFICATION_SERVICE_URL', target: 'notification' },
  { prefix: '/api/v1/merchant/notifications', urlEnv: 'NOTIFICATION_SERVICE_URL', target: 'notification' },

  // Merchant console (store-admin scoped). Order-service owns the order list;
  // merchant-service owns the store profile; catalog owns the product CRUD.
  // Declared before the broader catch-alls so each lands on its owner.
  { prefix: '/api/v1/merchant/orders', urlEnv: 'ORDER_SERVICE_URL', target: 'order' },
  { prefix: '/api/v1/merchant/products', urlEnv: 'CATALOG_SERVICE_URL', target: 'catalog' },
  { prefix: '/api/v1/merchant/categories', urlEnv: 'CATALOG_SERVICE_URL', target: 'catalog' },
  { prefix: '/api/v1/merchant/zones', urlEnv: 'DISPATCH_SERVICE_URL', target: 'dispatch' },
  { prefix: '/api/v1/merchant/settings', urlEnv: 'MERCHANT_SERVICE_URL', target: 'merchant' },

  // Payment service — payments.
  { prefix: '/api/v1/payments', urlEnv: 'PAYMENT_SERVICE_URL', target: 'payment' },
];

/**
 * Resolves the owner service for a request path (pathname only, no query).
 * Returns the first rule whose prefix matches exactly or as a path segment.
 */
export interface GatewayTarget {
  baseUrl: string;
  target: string;
  urlEnv: GatewayRoute['urlEnv'];
}

export function resolveTarget(path: string): GatewayTarget | null {
  if (/^\/api\/v1\/stores\/\d+\/(products|categories)(\/|$)/.test(path)) {
    const baseUrl = process.env.CATALOG_SERVICE_URL;
    return baseUrl ? { baseUrl, target: 'catalog', urlEnv: 'CATALOG_SERVICE_URL' } : null;
  }
  for (const rule of GATEWAY_ROUTES) {
    if (path === rule.prefix || path.startsWith(`${rule.prefix}/`)) {
      const baseUrl = process.env[rule.urlEnv];
      if (baseUrl === undefined || baseUrl === '') {
        return null;
      }
      return { baseUrl, target: rule.target, urlEnv: rule.urlEnv };
    }
  }
  return null;
}
