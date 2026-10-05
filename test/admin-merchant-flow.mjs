/**
 * TalaDelivery Admin / Merchant Surface E2E Test
 *
 * Covers the role-scoped notification feeds and the realtime fan-out added
 * after Phase 12:
 *   - rider application alerts platform admins (notification + realtime)
 *   - GET /admin/notifications is platform-admin only and returns the feed
 *   - GET /merchant/notifications is store-admin only, scoped by membership
 *   - a store admin cannot read the admin feed
 *   - merchant receives the full order lifecycle, not just order.created
 *   - realtime-feed queue drains with no discarded jobs
 *
 * Usage:
 *   node test/admin-merchant-flow.mjs
 */

import 'dotenv/config';

const IDENTITY_URL = process.env.IDENTITY_URL ?? 'http://localhost:3001';
const MERCHANT_URL = process.env.MERCHANT_URL ?? 'http://localhost:3002';
const CATALOG_URL = process.env.CATALOG_URL ?? 'http://localhost:3003';
const ORDER_URL = process.env.ORDER_URL ?? 'http://localhost:3004';
const DISPATCH_URL = process.env.DISPATCH_URL ?? 'http://localhost:3005';
const NOTIFICATION_URL = process.env.NOTIFICATION_URL ?? 'http://localhost:3007';
const APP_KEY = process.env.APP_API_KEY ?? 'change-me-dev-api-key';

const STORE_ID = 1;
const PRODUCT_ID = 1;

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (!condition) {
    console.error(`  FAIL: ${message}`);
    failed++;
    return false;
  }
  console.log(`  PASS: ${message}`);
  passed++;
  return true;
}

function ok(status) {
  return status === 200 || status === 201;
}

async function api(baseUrl, method, path, body, token) {
  const headers = { 'Content-Type': 'application/json', 'X-App-Key': APP_KEY };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${baseUrl}/api/v1${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, data: json };
}

async function login(email, password) {
  const res = await api(IDENTITY_URL, 'POST', '/auth/login', { email, password });
  return res.data?.data?.token ?? null;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(fn, { timeoutMs = 20000, intervalMs = 500, label = 'condition' } = {}) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    last = await fn();
    if (last) return last;
    await sleep(intervalMs);
  }
  console.error(`  (timed out after ${timeoutMs}ms waiting for ${label})`);
  return last;
}

// ─── Rider application must alert platform admins ──────────────────────
async function testRiderApplicationAlertsAdmin(adminToken) {
  console.log('\n=== Rider Application → Admin Alert ===');
  const email = `app_rider_${Date.now()}@test.com`;

  const reg = await api(IDENTITY_URL, 'POST', '/rider/register', {
    name: 'Applicant Rider',
    email,
    password: 'Rider@123456',
    phone: '09171234567',
    vehicle_type: 'BICYCLE',
    vehicle_plate: 'BIC-1',
  });
  if (!assert(ok(reg.status), `Rider application submitted (${reg.status})`)) return null;
  const userId = reg.data?.data?.user?.id;
  assert(userId != null, `Application returned the user id (${userId})`);

  const feed = await waitFor(
    async () => {
      const res = await api(NOTIFICATION_URL, 'GET', '/admin/notifications', null, adminToken);
      const items = res.data?.data?.data ?? [];
      return items.find((n) => n.data?.userId === userId) ?? null;
    },
    { timeoutMs: 20000, label: 'admin feed entry for the new application' },
  );

  if (!feed) {
    assert(false, 'Platform admin was alerted about the rider application');
    return null;
  }
  assert(true, `Platform admin alerted (notification ${feed.id}, type ${feed.type})`);
  assert(feed.type.startsWith('admin.'), `Alert uses the admin type namespace (${feed.type})`);
  assert(feed.is_read === false, 'Alert starts unread');
  return { userId, email };
}

// ─── Role scoping on the new endpoints ─────────────────────────────────
async function testRoleScoping(adminToken, merchantToken, customerToken) {
  console.log('\n=== Role Scoping ===');

  const asAdmin = await api(NOTIFICATION_URL, 'GET', '/admin/notifications', null, adminToken);
  assert(ok(asAdmin.status), `Admin can read /admin/notifications (${asAdmin.status})`);
  const meta = asAdmin.data?.data?.meta ?? {};
  assert(typeof meta.total === 'number', `Admin feed reports a total (${meta.total})`);
  assert(typeof meta.unread === 'number', `Admin feed reports unread (${meta.unread})`);
  assert(Array.isArray(meta.by_type), 'Admin feed breaks down by type');
  assert(Array.isArray(asAdmin.data?.data?.data), 'Admin feed returns an array');
  console.log(`  Admin by_type: ${JSON.stringify(meta.by_type)}`);

  const asMerchant = await api(NOTIFICATION_URL, 'GET', '/admin/notifications', null, merchantToken);
  assert(asMerchant.status === 403, `Store admin blocked from /admin/notifications (${asMerchant.status})`);

  const asCustomer = await api(NOTIFICATION_URL, 'GET', '/admin/notifications', null, customerToken);
  assert(asCustomer.status === 403, `Customer blocked from /admin/notifications (${asCustomer.status})`);

  const merchantFeed = await api(NOTIFICATION_URL, 'GET', '/merchant/notifications', null, merchantToken);
  assert(ok(merchantFeed.status), `Store admin can read /merchant/notifications (${merchantFeed.status})`);
  const storeMeta = merchantFeed.data?.data?.meta ?? {};
  assert(storeMeta.store?.id === STORE_ID, `Feed is scoped to store ${STORE_ID} (${storeMeta.store?.id})`);
  console.log(`  Merchant feed: total=${storeMeta.total} unread=${storeMeta.unread}`);

  const customerOnMerchant = await api(
    NOTIFICATION_URL,
    'GET',
    '/merchant/notifications',
    null,
    customerToken,
  );
  assert(
    customerOnMerchant.status === 403,
    `Customer blocked from /merchant/notifications (${customerOnMerchant.status})`,
  );

  // Per-user feed still works for every role.
  for (const [label, token] of [['admin', adminToken], ['merchant', merchantToken], ['customer', customerToken]]) {
    const res = await api(NOTIFICATION_URL, 'GET', '/notifications?per_page=5', null, token);
    assert(ok(res.status), `${label} can read the per-user feed (${res.status})`);
  }
}

// ─── Merchant sees the whole order lifecycle ───────────────────────────
async function testMerchantOrderLifecycle(merchantToken, customerToken) {
  console.log('\n=== Merchant Order Lifecycle Feed ===');

  const order = await api(
    ORDER_URL,
    'POST',
    '/orders',
    {
      storeId: STORE_ID,
      items: [{ productId: PRODUCT_ID, quantity: 1 }],
      deliveryAddress: '123 Test Street, Makati City',
      deliveryLatitude: '14.5547',
      deliveryLongitude: '121.0244',
      customerName: 'Scoped Customer',
      customerPhone: '09171234567',
      city: 'Makati City',
      province: 'Metro Manila',
    },
    customerToken,
  );
  if (!assert(ok(order.status), `Order created (${order.status})`)) return null;
  const orderId = order.data.data.id;

  const received = await waitFor(
    async () => {
      const res = await api(NOTIFICATION_URL, 'GET', '/merchant/notifications', null, merchantToken);
      const items = res.data?.data?.data ?? [];
      return items.find((n) => n.type === 'order.received' && n.data?.orderId === orderId) ?? null;
    },
    { timeoutMs: 20000, label: 'order.received for the store' },
  );
  assert(received != null, 'Store was notified of the new order');
  if (!received) return null;

  // Cancel it and confirm the store hears about that too.
  const cancel = await api(ORDER_URL, 'POST', `/orders/${orderId}/cancel`, { reason: 'E2E scoped test' }, customerToken);
  assert(ok(cancel.status), `Order cancelled (${cancel.status})`);

  const cancelled = await waitFor(
    async () => {
      const res = await api(NOTIFICATION_URL, 'GET', '/merchant/notifications', null, merchantToken);
      const items = res.data?.data?.data ?? [];
      return items.find((n) => n.type === 'order.cancelled' && n.data?.orderId === orderId) ?? null;
    },
    { timeoutMs: 20000, label: 'order.cancelled for the store' },
  );
  assert(cancelled != null, 'Store was notified of the cancellation');

  const customerSawCancel = await waitFor(
    async () => {
      const res = await api(NOTIFICATION_URL, 'GET', '/notifications?per_page=20', null, customerToken);
      const items = res.data?.data?.data ?? res.data?.data ?? [];
      return items.find((n) => n.type === 'order.cancelled' && n.data?.orderId === orderId) ?? null;
    },
    { timeoutMs: 20000, label: 'order.cancelled for the customer' },
  );
  assert(customerSawCancel != null, 'Customer was notified of the cancellation');

  // Mark-as-read is exposed and idempotent.
  const read = await api(NOTIFICATION_URL, 'POST', `/notifications/${received.id}/read`, {}, merchantToken);
  assert(ok(read.status), `Notification marked read (${read.status})`);
  assert(read.data?.data?.is_read === true, 'Read flag persisted');

  const again = await api(NOTIFICATION_URL, 'POST', `/notifications/${received.id}/read`, {}, merchantToken);
  assert(ok(again.status), `Mark-as-read is idempotent (${again.status})`);

  // A notification addressed to someone else must not be readable.
  const crossRead = await api(
    NOTIFICATION_URL,
    'POST',
    `/notifications/${received.id}/read`,
    {},
    customerToken,
  );
  assert(crossRead.status === 404, `Cross-user read is refused (${crossRead.status})`);

  return orderId;
}

// ─── Realtime fan-out actually reached the gateway ─────────────────────
async function testRealtimeFeedDrained() {
  console.log('\n=== Realtime Feed ===');
  const { Queue } = await import('bullmq');
  const queue = new Queue('realtime-feed', {
    connection: {
      host: process.env.REDIS_HOST ?? '127.0.0.1',
      port: Number.parseInt(process.env.REDIS_PORT ?? '6380', 10),
    },
    prefix: process.env.BULLMQ_PREFIX ?? 'bull',
  });
  try {
    const counts = await queue.getJobCounts('waiting', 'active', 'failed');
    assert(counts.failed === 0, `realtime-feed has no failed jobs (${counts.failed})`);
    assert(counts.waiting === 0, `realtime-feed drained (${counts.waiting} waiting)`);
    const completed = await queue.getJobCounts('completed');
    console.log(`  realtime-feed completed: ${completed.completed}`);
    assert(completed.completed > 0, 'realtime-feed carried at least one emit');
  } finally {
    await queue.close();
  }
}

// ─── Main ──────────────────────────────────────────────────────────────
async function main() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║      TalaDelivery Admin / Merchant Surface E2E Test         ║');
  console.log('╚════════════════════════════════════════════════════════════╝');

  const adminToken = await login('admin@taladelivery.com', 'Admin@123456');
  const merchantToken = await login('storeadmin@test.com', 'Store@123456');
  assert(adminToken !== null, 'Admin login');
  assert(merchantToken !== null, 'Store admin login');
  if (!adminToken || !merchantToken) return finish();

  const customerEmail = `scoped_${Date.now()}@test.com`;
  await api(IDENTITY_URL, 'POST', '/auth/register', {
    name: 'Scoped Customer',
    email: customerEmail,
    password: 'Test@123456',
  });
  const customerToken = await login(customerEmail, 'Test@123456');
  assert(customerToken !== null, 'Customer login');
  if (!customerToken) return finish();

  await testRiderApplicationAlertsAdmin(adminToken);
  await testRoleScoping(adminToken, merchantToken, customerToken);
  await testMerchantOrderLifecycle(merchantToken, customerToken);
  await testRealtimeFeedDrained();

  finish();
}

function finish() {
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log(`║  Results: ${passed} passed, ${failed} failed                          ║`);
  console.log('╚════════════════════════════════════════════════════════════╝');
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('Admin/merchant E2E failed:', error);
  process.exit(1);
});
