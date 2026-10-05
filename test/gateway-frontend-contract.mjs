/**
 * Verifies the Angular apps' backend contract end to end, through the same
 * paths the dev proxy uses.
 *
 * The admin and merchant consoles talk to the NestJS stack exclusively through
 * the API gateway, and the realtime gateway is reached over Socket.IO. This
 * asserts both, plus the two role-scoped notification feeds, so a gateway
 * routing regression is caught here rather than as an empty bell in the UI.
 *
 *   node test/gateway-frontend-contract.mjs
 */

import 'dotenv/config';
import { io } from 'socket.io-client';

const GATEWAY_URL = process.env.GATEWAY_URL ?? 'http://localhost:3000';
const REALTIME_URL = process.env.REALTIME_URL ?? 'http://localhost:3008';
const IDENTITY_URL = process.env.IDENTITY_URL ?? 'http://localhost:3001';
const APP_KEY = process.env.APP_API_KEY ?? 'change-me-dev-api-key';
const V1 = `${GATEWAY_URL}/api/v1`;

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

async function call(method, path, body, token) {
  const headers = { 'Content-Type': 'application/json', 'X-App-Key': APP_KEY };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${V1}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, data: json };
}

async function login(email, password) {
  const res = await call('POST', '/auth/login', { email, password });
  return res.data?.data?.token ?? null;
}

// ─── Gateway routing for everything the consoles call ──────────────────
async function testGatewayRoutes() {
  console.log('\n=== Gateway Routing ===');
  const adminToken = await login('admin@taladelivery.com', 'Admin@123456');
  if (!assert(adminToken !== null, 'Admin logs in through the gateway')) return null;

  const routes = [
    ['GET', '/admin/dashboard', 'dispatch (admin dashboard)'],
    ['GET', '/stores', 'merchant (store list)'],
    ['GET', '/products', 'catalog (product list)'],
    ['GET', '/notifications?per_page=5', 'notification (per-user feed)'],
    ['GET', '/admin/notifications?per_page=5', 'notification (ADMIN scoped feed)'],
  ];
  for (const [method, path, label] of routes) {
    const res = await call(method, path, null, adminToken);
    assert(res.status === 200, `${method} ${path} -> ${label} (${res.status})`);
  }
  return adminToken;
}

// ─── Role-scoped feeds behave through the gateway ───────────────────────
async function testScopedFeeds(adminToken) {
  console.log('\n=== Role-Scoped Feeds (via gateway) ===');

  const adminFeed = await call('GET', '/admin/notifications?per_page=5', null, adminToken);
  assert(adminFeed.status === 200, `Admin feed 200 (${adminFeed.status})`);
  const page = adminFeed.data?.data;
  assert(Array.isArray(page?.data), 'Admin feed returns an array in data.data');
  assert(typeof page?.meta?.total === 'number', `Admin feed meta.total present (${page?.meta?.total})`);
  assert(typeof page?.meta?.unread === 'number', `Admin feed meta.unread present (${page?.meta?.unread})`);
  assert(Array.isArray(page?.meta?.by_type), 'Admin feed meta.by_type present');
  console.log(`    by_type: ${JSON.stringify(page?.meta?.by_type ?? [])}`);

  const merchantToken = await login('storeadmin@test.com', 'Store@123456');
  if (!assert(merchantToken !== null, 'Store admin logs in through the gateway')) return;

  const merchantFeed = await call('GET', '/merchant/notifications?per_page=5', null, merchantToken);
  assert(merchantFeed.status === 200, `Merchant feed 200 (${merchantFeed.status})`);
  const store = merchantFeed.data?.data?.meta?.store;
  assert(store?.id === 1, `Merchant feed scoped to store 1 (${store?.id})`);

  // The admin feed must not be reachable by a store admin even via the gateway.
  const blocked = await call('GET', '/admin/notifications', null, merchantToken);
  assert(blocked.status === 403, `Store admin blocked from admin feed (${blocked.status})`);
}

// ─── Socket.IO gateway: auth, room authorization, live emit ────────────
async function testSocketGateway(adminToken, merchantToken) {
  console.log('\n=== Socket.IO Gateway ===');

  async function open(token) {
    const socket = io(`${REALTIME_URL}/realtime`, {
      transports: ['websocket'],
      auth: { token },
      reconnection: false,
    });
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('connect timeout')), 8000);
      socket.on('connect', () => {
        clearTimeout(timer);
        resolve(socket);
      });
      socket.on('connect_error', (err) => {
        clearTimeout(timer);
        reject(err);
      });
    });
  }

  /**
   * Subscribe acknowledgements go through the same `{ success, message, data }`
   * envelope as HTTP, so the gateway's own `{ success, error }` sits under
   * `data`. Unwrap it, otherwise every refusal reads as a pass.
   */
  function emitAck(socket, event, payload) {
    return new Promise((resolve) => {
      socket.emit(event, payload, (response) => resolve(response?.data ?? response));
    });
  }

  function waitFor(socket, event, timeoutMs = 10000) {
    return new Promise((resolve) => {
      const timer = setTimeout(() => resolve(null), timeoutMs);
      socket.once(event, (payload) => {
        clearTimeout(timer);
        resolve(payload);
      });
    });
  }

  // No token at all.
  let rejected = false;
  try {
    const anon = io(`${REALTIME_URL}/realtime`, { transports: ['websocket'], reconnection: false });
    await new Promise((resolve) => {
      const timer = setTimeout(resolve, 5000);
      anon.on('connect', () => {
        clearTimeout(timer);
        resolve();
      });
      anon.on('connect_error', () => {
        clearTimeout(timer);
        rejected = true;
        resolve();
      });
      anon.on('disconnect', () => {
        clearTimeout(timer);
        rejected = true;
        resolve();
      });
    });
    anon.close();
  } catch {
    rejected = true;
  }
  assert(rejected, 'Unauthenticated socket is rejected');

  const admin = await open(adminToken);
  assert(admin.connected, 'Admin socket connects with a valid token');

  const adminRoom = await emitAck(admin, 'subscribe', { room: 'admin:platform' });
  assert(adminRoom?.success === true, `Admin may join admin:platform (${JSON.stringify(adminRoom)})`);

  const userRoom = await emitAck(admin, 'subscribe', { room: 'user:1' });
  assert(userRoom?.success === true, 'Admin may join its own user room');

  // A platform admin must not be able to join another user's private room.
  const foreign = await emitAck(admin, 'subscribe', { room: 'user:99999' });
  assert(foreign?.success === false, `Admin refused a foreign user room (${JSON.stringify(foreign)})`);

  const noRoom = await emitAck(admin, 'subscribe', {});
  assert(noRoom?.success === false, 'Subscribe without a room is refused');

  // A store admin must not be able to join the platform admin room.
  const merchant = await open(merchantToken);
  assert(merchant.connected, 'Store admin socket connects');
  const merchantAdminRoom = await emitAck(merchant, 'subscribe', { room: 'admin:platform' });
  assert(
    merchantAdminRoom?.success === false,
    `Store admin refused admin:platform (${JSON.stringify(merchantAdminRoom)})`,
  );
  const merchantRoom = await emitAck(merchant, 'subscribe', { room: 'merchant:1' });
  assert(merchantRoom?.success === true, 'Store admin may join its merchant room');

  // A live platform event must reach the admin room and only the admin room.
  const adminSees = waitFor(admin, 'rider.application', 15000);
  const merchantSees = waitFor(merchant, 'rider.application', 15000);

  const rider = await call('POST', '/rider/register', {
    name: 'Gateway Rider',
    email: `gw_rider_${Date.now()}@test.com`,
    password: 'Rider@123456',
    vehicle_type: 'CAR',
  });
  assert(rider.status === 201 || rider.status === 200, `Rider application created (${rider.status})`);

  const got = await adminSees;
  if (assert(got !== null, 'admin:platform receives rider.application live')) {
    console.log(`    payload: ${JSON.stringify(got)}`);
  }
  const leaked = await merchantSees;
  assert(leaked === null, 'Store admin does NOT receive admin:platform events');

  admin.close();
  merchant.close();
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║      Gateway / Frontend Contract Test                      ║');
  console.log('╚════════════════════════════════════════════════════════════╝');

  const adminToken = await testGatewayRoutes();
  if (adminToken) {
    await testScopedFeeds(adminToken);
    const merchantToken = await login('storeadmin@test.com', 'Store@123456');
    await testSocketGateway(adminToken, merchantToken);
  }

  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log(`║  Results: ${passed} passed, ${failed} failed                          ║`);
  console.log('╚════════════════════════════════════════════════════════════╝');
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('Contract test failed:', error);
  process.exit(1);
});
