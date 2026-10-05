// Explicit sample-data seed: reuses Test Store and never overwrites existing products.
import 'dotenv/config';
import assert from 'node:assert/strict';
const api = 'http://localhost:3000/api/v1';
const appHeaders = { 'X-App-Key': process.env.APP_API_KEY, 'Content-Type': 'application/json' };
async function request(path, { token, storeId, method = 'GET', body } = {}) {
  const response = await fetch(`${api}/${path}`, { method, headers: {
    ...appHeaders, ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(storeId ? { 'X-Store-Id': String(storeId) } : {}),
  }, body: body == null ? undefined : JSON.stringify(body) });
  const result = await response.json();
  assert(response.ok, `${method} ${path}: ${response.status} ${result.message} ${JSON.stringify(result.errors ?? {})}`);
  return result.data;
}
const admin = await request('auth/login', { method: 'POST', body: {
  email: 'admin@taladelivery.com', password: 'Admin@123456',
} });
const merchant = await request('auth/login', { method: 'POST', body: {
  email: 'storeadmin@test.com', password: 'Store@123456',
} });
const matches = (await request('admin/stores?search=Test%20Store&per_page=100', { token: admin.token }))
  .data.filter((store) => store.name === 'Test Store');
assert(matches.length <= 1, 'More than one Test Store exists; choose explicitly before seeding.');
let store = matches[0];
if (!store) {
  store = await request('admin/stores', { token: admin.token, method: 'POST', body: {
    name: 'Test Store', address: '123 Test Street, Makati City', phone: '09171234567',
    latitude: '14.5547', longitude: '121.0244', status: 'ACTIVE',
  } });
  const membership = await fetch('http://localhost:3002/api/v1/internal/store-users', {
    method: 'POST', headers: { ...appHeaders, 'X-Service-Token': process.env.INTERNAL_API_TOKEN },
    body: JSON.stringify({ storeId: store.id, userId: merchant.user.id }),
  });
  assert(membership.ok, 'Assigning newly created sample store to the test merchant');
}
assert.equal(store.status, 'ACTIVE', 'Existing Test Store must be active; seed will not change its status.');
await request('store/profile', { token: merchant.token, storeId: store.id });
const options = { token: merchant.token, storeId: store.id };
const categories = (await request('store/categories', options)).data;
const ids = {};
for (const name of ['Sample Meals', 'Sample Drinks']) {
  const category = categories.find((category) => category.name === name)
    ?? await request('store/categories', { ...options, method: 'POST', body: { name, description: 'Sample menu for mobile checkout testing' } });
  ids[name] = category.id;
}
const existing = (await request('store/products', options)).data;
const samples = [
  { name: 'Sample Classic Burger', price: 99, category_id: ids['Sample Meals'], sku: 'TALA-SAMPLE-BURGER' },
  { name: 'Sample Chicken Rice Meal', price: 149, category_id: ids['Sample Meals'], sku: 'TALA-SAMPLE-RICE' },
  { name: 'Sample Iced Tea', price: 49, category_id: ids['Sample Drinks'], sku: 'TALA-SAMPLE-TEA' },
];
for (const sample of samples) {
  if (existing.some((product) => product.sku === sample.sku || product.name === sample.name)) {
    console.log(`Kept existing product: ${sample.name}`); continue;
  }
  const product = await request('store/products', { ...options, method: 'POST', body: {
    ...sample, stock: 50, is_available: true, description: 'Sample product for customer-to-merchant order testing',
  } });
  console.log(`Created product #${product.id}: ${product.name} (PHP ${product.price})`);
}
const visible = (await request(`products?store_id=${store.id}&per_page=100`)).data;
for (const sample of samples) assert(visible.some((product) => product.name === sample.name), 'Sample product is publicly available');
console.log(`Test Store #${store.id}: ${visible.length} available products. Existing store/product data preserved; no orders placed.`);
