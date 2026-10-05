// Read-only checks through the same proxy the merchant browser uses.
import 'dotenv/config';
import assert from 'node:assert/strict';
import { io } from 'socket.io-client';

const origin = process.env.MERCHANT_APP_URL ?? 'http://localhost:4300';
const api = `${origin}/api/v1`;
const headers = { 'Content-Type': 'application/json', 'X-App-Key': process.env.APP_API_KEY };
const login = await fetch(`${api}/auth/login`, { method: 'POST', headers,
  body: JSON.stringify({ email: 'storeadmin@test.com', password: 'Store@123456' }) });
assert([200, 201].includes(login.status), 'Merchant login through local NestJS gateway');
const auth = (await login.json()).data;
headers.Authorization = `Bearer ${auth.token}`;
const get = async (path, expected = 200, custom = headers) => {
  const response = await fetch(`${api}${path}`, { headers: custom });
  assert.equal(response.status, expected, path); return (await response.json()).data;
};
const profile = await get('/store/profile');
const storeId = profile.id;
assert(storeId, 'Merchant store membership is loaded from its profile');
headers['X-Store-Id'] = String(storeId);
assert.equal(profile.id, storeId);
const products = await get('/store/products'); assert(Array.isArray(products.data));
const categories = await get('/store/categories'); assert(Array.isArray(categories.data));
await get('/notifications');
const orders = await get('/store/orders?per_page=5'); assert(Array.isArray(orders.data));
assert(orders.data.every((order) => order.store.id === storeId));
for (const order of orders.data) assert.equal(typeof order.total, 'number');
let linkedOrder;
for (const status of ['PENDING', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']) {
  const result = await get(`/store/orders?status=${status}`);
  assert(result.data.every((order) => order.status === status));
  linkedOrder ??= result.data.find((order) => order.delivery_id != null);
}
if (linkedOrder) {
  const order = await get(`/store/orders/${linkedOrder.id}`);
  assert.equal(order.delivery.id, linkedOrder.delivery_id);
  assert.equal(typeof order.delivery.delivery_fee, 'number');
}
if (orders.data[0]) {
  const order = await get(`/store/orders/${orders.data[0].id}`);
  assert(Array.isArray(order.items));
  if (order.delivery_id) assert.equal(order.delivery.id, order.delivery_id);
}
await get('/store/orders', 404, { ...headers, 'X-Store-Id': '2147483647' });
await get('/store/profile', 404, { ...headers, 'X-Store-Id': '2147483647' });
await get('/store/products', 404, { ...headers, 'X-Store-Id': '2147483647' });
await get('/store/orders', 401, { 'X-App-Key': headers['X-App-Key'] });
await get('/admin/orders', 403);

const socket = io(`${origin}/realtime`, { auth: { token: auth.token }, transports: ['websocket'], reconnection: false });
try {
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(Error('Socket connection timeout')), 10000);
    socket.once('connect', () => { clearTimeout(timer); resolve(); });
    socket.once('connect_error', (error) => { clearTimeout(timer); reject(error); });
  });
  const subscribe = (room) => new Promise((resolve, reject) => socket.timeout(5000).emit('subscribe', { room },
    (error, result) => error ? reject(error) : resolve(result?.data ?? result)));
  assert.equal((await subscribe(`merchant:${storeId}`)).success, true);
  assert.equal((await subscribe('merchant:2147483647')).success, false);
  assert.equal((await subscribe('admin:platform')).success, false);
} finally { socket.disconnect(); }
console.log('PASS: merchant login, profile, products, categories, all order statuses/detail, notifications, authenticated realtime and store isolation through port 4300. No existing orders or products changed.');
