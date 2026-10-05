// Invalid product names guarantee these transport/validation checks save no rows.
import 'dotenv/config';
import assert from 'node:assert/strict';
const origin = 'http://localhost:4300/api/v1';
const headers = { 'Content-Type': 'application/json', 'X-App-Key': process.env.APP_API_KEY };
const login = await fetch(`${origin}/auth/login`, { method: 'POST', headers,
  body: JSON.stringify({ email: 'storeadmin@test.com', password: 'Store@123456' }) });
assert([200, 201].includes(login.status));
headers.Authorization = `Bearer ${(await login.json()).data.token}`;
const png = (size) => {
  const bytes = Buffer.alloc(size); Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]).copy(bytes);
  return `data:image/png;base64,${bytes.toString('base64')}`;
};
for (const size of [5 * 1024 * 1024, 5 * 1024 * 1024 + 1]) {
  const response = await fetch(`${origin}/store/products`, { method: 'POST', headers,
    body: JSON.stringify({ name: '', price: 0, image: png(size) }) });
  assert.equal(response.status, 422, 'Large JSON must reach DTO validation instead of failing transport');
  const error = await response.json();
  assert(error.errors?.name, 'Invalid name prevents saving test products');
  if (size === 5 * 1024 * 1024) assert(!error.errors?.image, 'A 5 MiB image is accepted');
  else assert(error.errors?.image, 'A file above 5 MiB is rejected');
}
console.log('PASS: 5 MiB Base64 payload passes gateway/catalog transport and image validation; oversized image rejected. No products saved.');
