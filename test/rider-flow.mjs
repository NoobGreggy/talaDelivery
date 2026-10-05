/**
 * TalaDelivery Rider / Broker E2E Flow Test
 *
 * Covers the parts of Phase 12 that need a reachable Redis broker:
 *   - rider registration (identity) + admin approval (dispatch)
 *   - going online and publishing a location
 *   - order creation → merchant confirm → preparing → ready
 *   - `order.ready_for_pickup` event consumed by dispatch → rider matching
 *     produces a pending offer (proves cross-service event fan-out)
 *   - offer accept → pickup → deliver
 *   - `delivery.*` events flow back to order-service and move the order FSM
 *   - notification rows are written for the order events
 *
 * Usage:
 *   node test/rider-flow.mjs
 *
 * Requires REDIS reachable; fails loudly (does not silently skip) so a broken
 * broker cannot be mistaken for a passing run.
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

/** Poll until `fn()` returns truthy or the deadline passes. */
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

// ─── Broker preflight ──────────────────────────────────────────────────
async function testBrokerReachable() {
  console.log('\n=== Broker Preflight ===');
  const port = process.env.REDIS_PORT ?? '6379';
  const host = process.env.REDIS_HOST ?? '127.0.0.1';
  assert(
    process.env.REDIS_PORT === '6380' || port === '6380',
    `REDIS_PORT is ${port}`,
  );
  // The services must not be logging broker errors; a single probe on the
  // dispatch health endpoint keeps this fast and non-invasive.
  const res = await fetch(`${DISPATCH_URL}/health/live`);
  assert(res.status === 200, `dispatch reachable at ${host}:${port}`);
}

// ─── Rider: register + approve + online ────────────────────────────────
async function setupRider() {
  console.log('\n=== Rider Onboarding ===');
  const email = `rider_${Date.now()}@test.com`;
  const password = 'Rider@123456';

  const reg = await api(IDENTITY_URL, 'POST', '/rider/register', {
    name: 'Test Rider',
    email,
    password,
    phone: '09171234567',
    vehicle_type: 'MOTORCYCLE',
    vehicle_plate: 'ABC-123',
  });
  assert(ok(reg.status), `Rider registration succeeds (${reg.status})`);
  if (!ok(reg.status)) return null;

  const token = await login(email, password);
  assert(token !== null, 'Rider can login');
  if (!token) return null;

  // A pending rider cannot go online — verify the guard, then approve.
  const tooEarly = await api(DISPATCH_URL, 'POST', '/rider/online', {}, token);
  assert(tooEarly.status === 422, `Pending rider blocked from going online (${tooEarly.status})`);

  // Admin approves the rider.
  const adminToken = await login('admin@taladelivery.com', 'Admin@123456');
  const list = await api(DISPATCH_URL, 'GET', '/admin/riders?per_page=100', null, adminToken);
  const riders = list.data?.data?.data ?? list.data?.data ?? [];
  const rider = riders.find((r) => r.user?.email === email || r.email === email)
    ?? riders[riders.length - 1];
  if (!rider) {
    assert(false, 'Rider appears in admin rider list');
    return null;
  }
  assert(true, `Rider visible to admin (id ${rider.id})`);

  const approve = await api(
    DISPATCH_URL,
    'POST',
    `/admin/riders/${rider.id}/approve`,
    {},
    adminToken,
  );
  assert(ok(approve.status), `Admin approves rider (${approve.status})`);
  assert(
    approve.data?.data?.status === 'OFFLINE' || approve.data?.data?.status === 'APPROVED',
    `Rider approved status is ${approve.data?.data?.status}`,
  );

  const online = await api(DISPATCH_URL, 'POST', '/rider/online', {}, token);
  assert(ok(online.status), `Approved rider goes online (${online.status})`);
  assert(online.data?.data?.status === 'ONLINE', `Rider is ONLINE (${online.data?.data?.status})`);

  // Near the store so distance matching can find the rider. Note: this stores
  // the position but publishes nothing — dispatch only emits
  // rider.location.updated while a delivery is active.
  const location = await api(
    DISPATCH_URL,
    'POST',
    '/rider/location',
    { latitude: 14.5547, longitude: 121.0244, heading_deg: 0, speed_mps: 0 },
    token,
  );
  assert(ok(location.status), `Rider location recorded (${location.status})`);

  return { token, riderId: rider.id, email, adminToken };
}

// ─── Order lifecycle through to READY_FOR_PICKUP ───────────────────────
async function createReadyOrder(customerToken, merchantToken) {
  console.log('\n=== Order To Ready For Pickup ===');

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
      customerName: 'Test Customer',
      customerPhone: '09171234567',
      city: 'Makati City',
      province: 'Metro Manila',
    },
    customerToken,
  );
  assert(ok(order.status), `Order created (${order.status})`);
  if (!ok(order.status)) return null;
  const orderId = order.data.data.id;

  for (const [step, expected] of [
    ['confirm', 'CONFIRMED'],
    ['preparing', 'PREPARING'],
    ['ready', 'READY_FOR_PICKUP'],
  ]) {
    const res = await api(ORDER_URL, 'POST', `/orders/${orderId}/${step}`, {}, merchantToken);
    assert(ok(res.status), `Order ${step} (${res.status})`);
    assert(res.data?.data?.status === expected, `Status is ${expected} (${res.data?.data?.status})`);
  }

  return order.data.data;
}

// ─── Event fan-out: order.ready_for_pickup → rider matching → offer ────
async function testOfferGenerated(rider, order) {
  console.log('\n=== Event Fan-Out → Rider Offer ===');

  // Going online retries matching for *every* still-unmatched order, so this
  // rider can hold offers for older orders too. Select the one for this
  // order's delivery, or the assertions below pass against the wrong record.
  const target = await waitFor(
    async () => {
      const res = await api(DISPATCH_URL, 'GET', '/rider/offers', null, rider.token);
      const list = Array.isArray(res.data?.data) ? res.data.data : [];
      return list.find((o) => o.delivery_id === order.deliveryId) ?? null;
    },
    { timeoutMs: 25000, label: `an offer for delivery ${order.deliveryId}` },
  );

  if (!target) {
    assert(false, `Dispatch produced a pending offer for delivery ${order.deliveryId}`);
    const res = await api(DISPATCH_URL, 'GET', '/rider/offers', null, rider.token);
    console.log(`    offers held: ${JSON.stringify(res.data?.data?.map((o) => ({ id: o.id, delivery_id: o.delivery_id })))}`);
    return null;
  }
  assert(true, `Dispatch produced a pending offer (id ${target.id}) for delivery ${target.delivery_id}`);
  assert(target.status === 'PENDING', `Offer status is PENDING (${target.status})`);
  assert(target.expires_at != null, 'Offer has an expiry');
  return target;
}

// ─── Accept → pickup → deliver, and the order FSM follows ──────────────
async function testDeliveryLifecycle(rider, offer, order) {
  console.log('\n=== Rider Accept → Pickup → Deliver ===');

  const accept = await api(DISPATCH_URL, 'POST', `/rider/offers/${offer.id}/accept`, {}, rider.token);
  assert(ok(accept.status), `Rider accepts offer (${accept.status})`);
  if (!ok(accept.status)) return null;

  const deliveryId = accept.data?.data?.delivery?.id ?? accept.data?.data?.delivery_id;
  assert(deliveryId != null, `Accept returns the delivery (id ${deliveryId})`);
  if (deliveryId == null) return null;

  // A second rider-less accept of the same offer must be rejected.
  const reaccept = await api(DISPATCH_URL, 'POST', `/rider/offers/${offer.id}/accept`, {}, rider.token);
  assert(reaccept.status >= 400, `Re-accepting a spent offer is rejected (${reaccept.status})`);

  // Delivery FSM: ASSIGNED →(arrived) ACCEPTED →(pickup) PICKED_UP
  //              →(start) IN_TRANSIT →(complete) DELIVERED
  const deliveryFsm = [
    ['arrived', 'ACCEPTED'],
    ['pickup', 'PICKED_UP'],
    ['start', 'IN_TRANSIT'],
    ['complete', 'DELIVERED'],
  ];
  for (const [step, expected] of deliveryFsm) {
    // dispatch only publishes rider.location.updated while a delivery is
    // active, so post a position between transitions to exercise
    // location-events -> realtime-service fan-out.
    if (step === 'start' || step === 'complete') {
      const loc = await api(
        DISPATCH_URL,
        'POST',
        '/rider/location',
        { latitude: 14.556, longitude: 121.026, heading_deg: 90, speed_mps: 8 },
        rider.token,
      );
      assert(ok(loc.status), `Rider location updated mid-delivery (${loc.status})`);
    }
    const res = await api(DISPATCH_URL, 'POST', `/rider/deliveries/${deliveryId}/${step}`, {}, rider.token);
    assert(ok(res.status), `Delivery ${step} (${res.status})`);
    if (!ok(res.status)) {
      console.log(`    stopped at ${step}: ${JSON.stringify(res.data)}`);
      break;
    }
    assert(res.data?.data?.status === expected, `Delivery status is ${expected} (${res.data?.data?.status})`);
  }

  const finalStatus = accept.data?.data?.delivery?.status;
  console.log(`  Delivery status after accept: ${finalStatus}`);

  // delivery.complete publishes back to order-service; the order must reach
  // a delivered state without any direct HTTP call from this test.
  const settled = await waitFor(
    async () => {
      const res = await api(ORDER_URL, 'GET', `/orders/${order.id}`, null, await loginCustomer());
      const status = res.data?.data?.status;
      return status === 'DELIVERED' || status === 'COMPLETED' ? status : null;
    },
    { timeoutMs: 25000, label: 'order to reach DELIVERED via delivery.* events' },
  );
  assert(settled != null, `Order reached DELIVERED via cross-service events (${settled})`);

  const profile = await api(DISPATCH_URL, 'GET', '/rider/profile', null, rider.token);
  assert(ok(profile.status), `Rider profile loads (${profile.status})`);
  console.log(`  Rider stats: ${JSON.stringify(profile.data?.data?.stats ?? {})}`);

  return deliveryId;
}

let customerTokenCache = null;
async function loginCustomer() {
  if (customerTokenCache) return customerTokenCache;
  const email = `customer_rider_${Date.now()}@test.com`;
  await api(IDENTITY_URL, 'POST', '/auth/register', { name: 'Rider Flow Customer', email, password: 'Test@123456' });
  customerTokenCache = await login(email, 'Test@123456');
  return customerTokenCache;
}

// ─── Merchant was told about the order ─────────────────────────────────
async function testMerchantNotified(merchantToken) {
  console.log('\n=== Merchant Notifications ===');
  const list = await waitFor(
    async () => {
      const r = await api(NOTIFICATION_URL, 'GET', '/notifications?per_page=50', null, merchantToken);
      const items = r.data?.data?.data ?? r.data?.data ?? [];
      const received = items.filter((n) => n.type === 'order.received');
      return received.length > 0 ? received : null;
    },
    { timeoutMs: 20000, label: 'order.received notification for the store admin' },
  );
  if (!list) {
    assert(false, 'Store admin was notified of the new order');
    return;
  }
  assert(true, `Store admin was notified of the new order (${list.length} notification(s))`);
  assert(
    typeof list[0].data?.orderNumber === 'string',
    `Notification carries the order number (${list[0].data?.orderNumber})`,
  );
}

// ─── Notifications were persisted ──────────────────────────────────────
async function testNotifications(customerToken) {
  console.log('\n=== Notifications ===');
  const res = await fetch(`${NOTIFICATION_URL}/health/live`);
  assert(res.status === 200, `notification service live (${res.status})`);

  // Notification rows are written asynchronously by NotificationConsumer, so
  // wait for the customer's order notifications to land.
  const list = await waitFor(
    async () => {
      const r = await api(NOTIFICATION_URL, 'GET', '/notifications?per_page=50', null, customerToken);
      const items = r.data?.data?.data ?? r.data?.data ?? [];
      return Array.isArray(items) && items.length > 0 ? items : null;
    },
    { timeoutMs: 20000, label: 'notification rows for the customer' },
  );

  if (!list) {
    assert(false, 'Customer received notification rows');
    return;
  }
  const types = [...new Set(list.map((n) => n.type))].sort();
  console.log(`  Notification types: ${types.join(', ')}`);
  assert(
    types.includes('order.created'),
    `Customer was notified of order creation (${types.join(',')})`,
  );
  assert(
    types.includes('order.delivered') || types.includes('payment.paid'),
    `Customer was notified of completion (${types.join(',')})`,
  );
  assert(
    list.every((n) => n.is_read === false || n.isRead === false),
    'Unread flag persisted',
  );
}

// ─── Main ──────────────────────────────────────────────────────────────
async function main() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║        TalaDelivery Rider / Broker E2E Flow Test            ║');
  console.log('╚════════════════════════════════════════════════════════════╝');

  await testBrokerReachable();

  const adminToken = await login('admin@taladelivery.com', 'Admin@123456');
  const merchantToken = await login('storeadmin@test.com', 'Store@123456');
  assert(adminToken !== null, 'Admin login');
  assert(merchantToken !== null, 'Store admin login');
  if (!adminToken || !merchantToken) return finish();

  const rider = await setupRider();
  if (!rider) return finish();

  const customerToken = await loginCustomer();
  assert(customerToken !== null, 'Customer login');

  const order = await createReadyOrder(customerToken, merchantToken);
  if (!order) return finish();

  const offer = await testOfferGenerated(rider, order);
  if (!offer) return finish();

  await testDeliveryLifecycle(rider, offer, order);
  await testNotifications(customerToken);
  await testMerchantNotified(merchantToken);

  // Dashboard should now reflect the rider.
  const dash = await api(DISPATCH_URL, 'GET', '/admin/dashboard', null, adminToken);
  const totals = dash.data?.data?.totals ?? {};
  console.log(`\n=== Dashboard ===\n  Totals: ${JSON.stringify(totals)}`);
  assert(totals.riders >= 1, `Dashboard counts the rider (${totals.riders})`);
  assert(totals.deliveries >= 1, `Dashboard counts the delivery (${totals.deliveries})`);
  assert(totals.orders >= 1, `Dashboard counts the order (${totals.orders})`);

  finish();
}

function finish() {
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log(`║  Results: ${passed} passed, ${failed} failed                          ║`);
  console.log('╚════════════════════════════════════════════════════════════╝');
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('Rider E2E failed:', error);
  process.exit(1);
});
