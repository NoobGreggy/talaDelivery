// Read-only LAN checks. No orders, addresses or notifications are created.
import 'dotenv/config';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import pg from 'pg';
import bcrypt from 'bcryptjs';
import { io } from 'socket.io-client';

const config = JSON.parse(readFileSync('../talaDelivery-customer/config/local.json', 'utf8'));
assert.equal(config.TALA_API_KEY, process.env.APP_API_KEY, 'Mobile app key must match backend');
const api = config.TALA_API_BASE_URL.replace(/\/$/, '');
const headers = { 'X-App-Key': config.TALA_API_KEY, 'Content-Type': 'application/json' };
async function get(path, authenticated = false) {
  const response = await fetch(`${api}/${path}`, { headers: authenticated ? headers : { 'X-App-Key': config.TALA_API_KEY } });
  assert.equal(response.status, 200, path);
  return (await response.json()).data;
}
const categories = await get('store-categories');
assert(categories.every((category) => category.is_active && typeof category.icon === 'string'));
const stores = await get('stores');
assert(Array.isArray(stores));
for (const store of stores.slice(0, 3)) {
  assert(Array.isArray(await get(`stores/${store.id}/categories`)), 'Store product category route');
  const products = await get(`products?store_id=${store.id}&per_page=100`);
  assert(products.data.every((product) => product.storeId === store.id), 'Products stay in selected store');
}
// Reuse an existing disposable E2E customer when available; never register one.
assert(['localhost', '127.0.0.1', '::1'].includes(process.env.POSTGRES_HOST ?? 'localhost'));
const db = new pg.Client({ host: process.env.POSTGRES_HOST, port: Number(process.env.POSTGRES_PORT),
  user: process.env.POSTGRES_USER, password: process.env.POSTGRES_PASSWORD, database: 'taladelivery_identity' });
await db.connect();
let customer;
try {
  const users = await db.query("SELECT id, email, password FROM users WHERE role = 'customer' AND status = 'ACTIVE' AND email LIKE 'customer_%@test.com' ORDER BY id DESC LIMIT 30");
  for (const user of users.rows) {
    if (await bcrypt.compare('Test@123456', user.password)) { customer = user; break; }
  }
} finally { await db.end(); }
if (customer) {
  const response = await fetch(`${api}/auth/login`, { method: 'POST', headers,
    body: JSON.stringify({ email: customer.email, password: 'Test@123456' }) });
  assert([200, 201].includes(response.status));
  const login = (await response.json()).data;
  headers.Authorization = `Bearer ${login.token}`;
  assert(Array.isArray(await get('addresses', true)));
  assert(Array.isArray((await get('orders', true)).data));
  const quoteRequest = { storeId: 1, deliveryLatitude: '14.557', deliveryLongitude: '121.027', city: 'Makati City', province: 'Metro Manila' };
  const before = (await get('orders', true)).meta.total;
  const quoteResponse = await fetch(`${api}/orders/delivery-quote`, { method: 'POST', headers, body: JSON.stringify(quoteRequest) });
  const quote = await quoteResponse.json();
  if (quoteResponse.ok) {
    assert(Number.isFinite(Number(quote.data.deliveryFee)) && Number(quote.data.deliveryFee) >= 0);
    assert.equal(typeof quote.data.zone.name, 'string');
    console.log(`PASS: Test Store delivery quote: PHP ${quote.data.deliveryFee} (${quote.data.zone.name}).`);
  } else {
    assert.equal(quoteResponse.status, 422);
    assert.match(quote.message, /Delivery is not available|Delivery distance exceeds|Road distance/i);
    console.log(`PASS: unavailable zone returns a customer-facing 422: ${quote.message}`);
  }
  assert.equal((await get('orders', true)).meta.total, before, 'Fee quoting must not create an order');
  const invalidQuote = await fetch(`${api}/orders/delivery-quote`, { method: 'POST', headers,
    body: JSON.stringify({ ...quoteRequest, deliveryLatitude: '91' }) });
  assert.equal(invalidQuote.status, 422);
  assert((await invalidQuote.json()).errors.deliveryLatitude);
  const unauthenticatedQuote = await fetch(`${api}/orders/delivery-quote`, { method: 'POST', headers: { 'X-App-Key': config.TALA_API_KEY, 'Content-Type': 'application/json' }, body: JSON.stringify(quoteRequest) });
  assert.equal(unauthenticatedQuote.status, 401);
  const socket = io(`${config.TALA_SOCKET_IO_URL}/realtime`, {
    auth: { token: login.token }, transports: ['websocket'], reconnection: false,
  });
  try {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('LAN realtime subscription timed out')), 8000);
      socket.once('connect_error', (error) => { clearTimeout(timer); reject(error); });
      socket.once('connect', () => socket.emit('subscribe', { room: `user:${login.user.id}` }, (reply) => {
        clearTimeout(timer);
        try { assert.equal(reply.data?.success ?? reply.success, true); resolve(); } catch (error) { reject(error); }
      }));
    });
  } finally { socket.disconnect(); }
  console.log('PASS: LAN customer login, saved address list, orders and authenticated Socket.IO user subscription.');
} else {
  console.log('SKIP: customer authentication check requires an existing disposable E2E customer.');
}
console.log('PASS: mobile app key, active category icons, selected-store products and category gateway routes over LAN.');
