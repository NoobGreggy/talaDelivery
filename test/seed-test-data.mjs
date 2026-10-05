/**
 * Seed test data: store + products for E2E testing.
 * Run after services are up: node test/seed-test-data.mjs
 */
import 'dotenv/config';

const MERCHANT_URL = process.env.MERCHANT_URL ?? 'http://localhost:3002';
const CATALOG_URL = process.env.CATALOG_URL ?? 'http://localhost:3003';
const APP_KEY = process.env.APP_API_KEY ?? 'change-me-dev-api-key';
const ADMIN_EMAIL = process.env.SEED_ADMIN_EMAIL ?? 'admin@taladelivery.com';
const ADMIN_PASSWORD = process.env.SEED_ADMIN_PASSWORD ?? 'Admin@123456';

async function api(baseUrl, method, path, body, token) {
  const headers = { 'Content-Type': 'application/json', 'X-App-Key': APP_KEY };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${baseUrl}/api/v1${path}`, {
    method, headers, body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, data: await res.json().catch(() => ({})) };
}

async function login(email, password) {
  const res = await api('http://localhost:3001', 'POST', '/auth/login', { email, password });
  return res.data?.data?.token ?? null;
}

async function main() {
  console.log('Seeding test data...\n');

  const adminToken = await login(ADMIN_EMAIL, ADMIN_PASSWORD);
  if (!adminToken) { console.error('Admin login failed'); process.exit(1); }

  // Create store
  const storeRes = await api(MERCHANT_URL, 'POST', '/stores', {
    name: 'Test Store',
    address: '123 Test Street, Makati City',
    phone: '09171234567',
    latitude: '14.5547',
    longitude: '121.0244',
  }, adminToken);

  if (storeRes.status !== 201 && storeRes.status !== 200) {
    console.error('Failed to create store:', storeRes.data);
    process.exit(1);
  }

  const store = storeRes.data?.data;
  console.log(`Store created: ${store.name} (id: ${store.id})`);

  // Create products
  const products = [
    { name: 'Test Product 1', price: '99.00', stock: 10, description: 'Test product 1' },
    { name: 'Test Product 2', price: '149.00', stock: 5, description: 'Test product 2' },
    { name: 'Test Product 3', price: '199.00', stock: 3, description: 'Test product 3' },
  ];

  for (const p of products) {
    const res = await api(CATALOG_URL, 'POST', '/merchant/products', {
      storeId: store.id,
      name: p.name,
      price: p.price,
      stock: p.stock,
      description: p.description,
    }, adminToken);
    if (res.status !== 201 && res.status !== 200) {
      console.error(`Failed to create product ${p.name}:`, res.data);
    } else {
      console.log(`Product created: ${p.name} (id: ${res.data?.data?.id})`);
    }
  }

  console.log('\nTest data seeded successfully!');
  console.log(`Store ID: ${store.id}`);
  console.log(`Store slug: ${store.slug}`);
}

main().catch((error) => { console.error('Seed failed:', error); process.exit(1); });
