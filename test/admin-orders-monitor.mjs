// Read-only checks against the same admin origin used by the browser.
import 'dotenv/config';
import assert from 'node:assert/strict';

const origin = process.env.ADMIN_URL ?? 'http://localhost:4200';
const api = `${origin}/api/v1`;
const headers = { 'Content-Type': 'application/json', 'X-App-Key': process.env.APP_API_KEY ?? 'change-me-dev-api-key' };
const login = await fetch(`${api}/auth/login`, { method: 'POST', headers,
  body: JSON.stringify({ email: process.env.ADMIN_EMAIL ?? 'admin@taladelivery.com', password: process.env.ADMIN_PASSWORD ?? 'Admin@123456' }) });
assert([200, 201].includes(login.status), 'Admin login through Angular proxy');
const token = (await login.json()).data.token;
headers.Authorization = `Bearer ${token}`;

const list = await fetch(`${api}/admin/orders?per_page=5`, { headers });
assert.equal(list.status, 200, 'Admin orders list must be available');
const body = await list.json();
assert(Array.isArray(body.data.data));
assert.equal(typeof body.data.meta.total, 'number');
for (const order of body.data.data) {
  assert.equal(typeof order.order_number, 'string');
  assert.equal(typeof order.total, 'number');
  assert.equal(typeof order.created_at, 'string');
  assert(order.customer?.name);
  assert(order.store?.name);
}
const statuses = ['PENDING', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED'];
for (const status of statuses) {
  const response = await fetch(`${api}/admin/orders?status=${status}&per_page=5`, { headers });
  assert.equal(response.status, 200, `Status ${status} must be monitorable`);
  const page = (await response.json()).data;
  assert(page.data.every((order) => order.status === status), `${status} filtering must happen on the server`);
}
if (body.data.data.length) {
  const order = body.data.data[0];
  const detail = await fetch(`${api}/admin/orders/${order.id}`, { headers });
  assert.equal(detail.status, 200, 'Order detail is available to admin');
  const data = (await detail.json()).data;
  assert.equal(data.order_number, order.order_number);
  assert(Array.isArray(data.items));
  for (const item of data.items) { assert.equal(typeof item.price, 'number'); assert(item.product?.name); }
  const response = await fetch(`${api}/admin/orders?search=${encodeURIComponent(order.order_number)}`, { headers });
  const matching = (await response.json()).data;
  assert(matching.data.some((entry) => entry.id === order.id), 'Search finds the order across the entire list');
}
const denied = await fetch(`${api}/admin/orders`, { headers: { 'X-App-Key': headers['X-App-Key'] } });
assert.equal(denied.status, 401, 'Order monitoring requires authentication');
const publicHeaders = { 'X-App-Key': headers['X-App-Key'] };
const categories = await fetch(`${api}/store-categories`, { headers: publicHeaders });
assert.equal(categories.status, 200, 'Future customer category list does not require login');
const categoryList = (await categories.json()).data;
assert(Array.isArray(categoryList));
assert(categoryList.every((category) => category.is_active === true), 'Customers see only active categories');
const adminCategories = await fetch(`${api}/admin/store-categories`, { headers });
assert.equal(adminCategories.status, 200, 'Admin category management list is available');
assert(Array.isArray((await adminCategories.json()).data));
const deniedCategories = await fetch(`${api}/admin/store-categories`, { headers: publicHeaders });
assert.equal(deniedCategories.status, 401, 'Category management requires authentication');
const stores = await fetch(`${api}/stores?category=2147483647`, { headers: publicHeaders });
assert.equal(stores.status, 200, 'Customer store list accepts a category filter');
assert.deepEqual((await stores.json()).data, [], 'Unassigned category does not return unrelated stores');
console.log(`PASS: admin list/detail, every status, server search, UI field shapes and authentication through ${origin}. ${body.data.meta.total} orders available.`);
console.log('PASS: public active category API, category-filtered stores, admin categories and authentication.');
