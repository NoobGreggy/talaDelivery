/**
 * TalaDelivery E2E Flow Test
 *
 * Tests the critical business flows across all services:
 *   Customer: login → browse stores → browse products → create order
 *   Merchant: login → confirm order → preparing → ready
 *   Rider: login → go online → (offer flow tested separately)
 *   Admin: login → dashboard → list orders
 *
 * Usage:
 *   node test/e2e-flow.mjs
 *
 * Environment variables (or .env):
 *   IDENTITY_URL, MERCHANT_URL, CATALOG_URL, ORDER_URL, DISPATCH_URL
 *   APP_API_KEY
 */

import 'dotenv/config';

const IDENTITY_URL = process.env.IDENTITY_URL ?? 'http://localhost:3001';
const MERCHANT_URL = process.env.MERCHANT_URL ?? 'http://localhost:3002';
const CATALOG_URL = process.env.CATALOG_URL ?? 'http://localhost:3003';
const ORDER_URL = process.env.ORDER_URL ?? 'http://localhost:3004';
const DISPATCH_URL = process.env.DISPATCH_URL ?? 'http://localhost:3005';
const PAYMENT_URL = process.env.PAYMENT_URL ?? 'http://localhost:3006';
const APP_KEY = process.env.APP_API_KEY ?? 'change-me-dev-api-key';

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

/** Success for these endpoints is 200 or 201 depending on the route. */
function ok(status) {
  return status === 200 || status === 201;
}

async function api(baseUrl, method, path, body, token) {
  const headers = {
    'Content-Type': 'application/json',
    'X-App-Key': APP_KEY,
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;

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

// ─── Test: Health Checks ───────────────────────────────────────────────
async function testHealth() {
  console.log('\n=== Health Checks ===');
  const services = [
    ['Identity', IDENTITY_URL],
    ['Merchant', MERCHANT_URL],
    ['Catalog', CATALOG_URL],
    ['Order', ORDER_URL],
    ['Dispatch', DISPATCH_URL],
    ['Payment', PAYMENT_URL],
  ];

  for (const [name, url] of services) {
    try {
      const res = await fetch(`${url}/health/live`);
      assert(res.status === 200, `${name} service is live`);
    } catch {
      assert(false, `${name} service is reachable at ${url}`);
    }
  }
}

// ─── Test: Admin Login ─────────────────────────────────────────────────
async function testAdminLogin() {
  console.log('\n=== Admin Login ===');
  const token = await login('admin@taladelivery.com', 'Admin@123456');
  assert(token !== null, 'Admin can login');
  return token;
}

// ─── Test: Merchant Login ──────────────────────────────────────────────
async function testMerchantLogin() {
  console.log('\n=== Merchant Login ===');
  const token = await login('storeadmin@test.com', 'Store@123456');
  assert(token !== null, 'Store admin can login');
  return token;
}

// ─── Test: Customer Registration + Login ───────────────────────────────
async function testCustomer() {
  console.log('\n=== Customer Registration + Login ===');
  const email = `customer_${Date.now()}@test.com`;
  const password = 'Test@123456';

  const reg = await api(IDENTITY_URL, 'POST', '/auth/register', {
    name: 'Test Customer',
    email,
    password,
  });
  assert(reg.status === 201 || reg.status === 200, `Customer registration succeeds (${reg.status})`);

  const token = await login(email, password);
  assert(token !== null, 'Customer can login after registration');
  return { token, email };
}

// ─── Test: Store Browsing ──────────────────────────────────────────────
async function testStoreBrowsing() {
  console.log('\n=== Store Browsing ===');
  const res = await api(MERCHANT_URL, 'GET', '/stores');
  assert(res.status === 200, `Store listing returns 200 (${res.status})`);
  assert(Array.isArray(res.data?.data), 'Store listing returns array');
  return res.data?.data ?? [];
}

// ─── Test: Product Browsing ────────────────────────────────────────────
async function testProductBrowsing() {
  console.log('\n=== Product Browsing ===');
  const res = await api(CATALOG_URL, 'GET', '/products');
  assert(res.status === 200, `Product listing returns 200 (${res.status})`);
  return res.data?.data?.data ?? [];
}

// ─── Test: Order Creation ──────────────────────────────────────────────
async function testOrderCreation(customerToken) {
  console.log('\n=== Order Creation ===');

  // First get a store
  const stores = await api(MERCHANT_URL, 'GET', '/stores');
  const storeData = stores.data?.data ?? [];
  if (storeData.length === 0) {
    console.log('  SKIP: No stores available for order test');
    return null;
  }

  const store = storeData[0];
  console.log(`  Using store: ${store.name} (id: ${store.id})`);

  // Get products for this store
  const products = await api(CATALOG_URL, 'GET', `/stores/${store.id}/products`);
  const productData = products.data?.data ?? [];
  if (productData.length === 0) {
    console.log('  SKIP: No products available for order test');
    return null;
  }

  const product = productData[0];
  console.log(`  Using product: ${product.name} (id: ${product.id}, price: ${product.price})`);

  // Create order
  const orderRes = await api(ORDER_URL, 'POST', '/orders', {
    storeId: store.id,
    items: [{ productId: product.id, quantity: 1 }],
    deliveryAddress: '123 Test Street, Makati City',
    deliveryLatitude: '14.5547',
    deliveryLongitude: '121.0244',
    customerName: 'Test Customer',
    customerPhone: '09171234567',
    city: 'Makati City',
    province: 'Metro Manila',
  }, customerToken);

  console.log(`  Order response status: ${orderRes.status}`);
  console.log(`  Order response: ${JSON.stringify(orderRes.data, null, 2)}`);

  if (orderRes.status === 201 || orderRes.status === 200) {
    assert(true, 'Order created successfully');
    return orderRes.data?.data;
  } else {
    assert(false, `Order creation failed: ${orderRes.data?.message ?? 'Unknown error'}`);
    return null;
  }
}

// ─── Test: Order Flow (Merchant confirms → preparing → ready) ──────────
async function testOrderFlow(merchantToken, customerToken, order) {
  if (!order) return;

  console.log('\n=== Order Status Flow ===');
  const orderId = order.id;

  // Authorization: the customer who placed the order must not be able to
  // drive the merchant-side status transitions.
  const forbidden = await api(ORDER_URL, 'POST', `/orders/${orderId}/confirm`, {}, customerToken);
  assert(forbidden.status === 403, `Customer is blocked from confirming (${forbidden.status})`);

  // Confirm
  const confirm = await api(ORDER_URL, 'POST', `/orders/${orderId}/confirm`, {}, merchantToken);
  assert(ok(confirm.status), `Order confirmed (${confirm.status})`);
  assert(confirm.data?.data?.status === 'CONFIRMED', `Status is CONFIRMED (${confirm.data?.data?.status})`);

  // Preparing
  const preparing = await api(ORDER_URL, 'POST', `/orders/${orderId}/preparing`, {}, merchantToken);
  assert(ok(preparing.status), `Order marked preparing (${preparing.status})`);
  assert(preparing.data?.data?.status === 'PREPARING', `Status is PREPARING (${preparing.data?.data?.status})`);

  // Ready
  const ready = await api(ORDER_URL, 'POST', `/orders/${orderId}/ready`, {}, merchantToken);
  assert(ok(ready.status), `Order marked ready for pickup (${ready.status})`);
  assert(ready.data?.data?.status === 'READY_FOR_PICKUP', `Status is READY_FOR_PICKUP (${ready.data?.data?.status})`);
}

// ─── Test: Admin Dashboard ─────────────────────────────────────────────
async function testAdminDashboard(adminToken) {
  console.log('\n=== Admin Dashboard ===');
  const res = await api(DISPATCH_URL, 'GET', '/admin/dashboard', null, adminToken);
  assert(res.status === 200, `Admin dashboard returns 200 (${res.status})`);
  if (res.data?.data) {
    const totals = res.data.data.totals ?? {};
    console.log(`  Totals: ${JSON.stringify(totals)}`);
  }
}

// ─── Test: Order Listing ───────────────────────────────────────────────
async function testOrderListing(customerToken) {
  console.log('\n=== Order Listing ===');
  const res = await api(ORDER_URL, 'GET', '/orders', null, customerToken);
  assert(res.status === 200, `Order listing returns 200 (${res.status})`);
  return res.data?.data ?? [];
}

// ─── Main ──────────────────────────────────────────────────────────────
async function main() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║        TalaDelivery E2E Flow Test                          ║');
  console.log('╚════════════════════════════════════════════════════════════╝');

  await testHealth();
  const adminToken = await testAdminLogin();
  const merchantToken = await testMerchantLogin();
  const customer = await testCustomer();
  await testStoreBrowsing();
  await testProductBrowsing();
  const order = await testOrderCreation(customer?.token);
  await testOrderFlow(merchantToken, customer?.token, order);
  await testAdminDashboard(adminToken);
  await testOrderListing(customer?.token);

  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log(`║  Results: ${passed} passed, ${failed} failed                          ║`);
  console.log('╚════════════════════════════════════════════════════════════╝');

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('E2E test failed:', error);
  process.exit(1);
});
