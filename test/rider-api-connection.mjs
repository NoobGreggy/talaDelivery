// Read-only rider API checks; broker probes target an unused synthetic user.
// Does not go online, accept offers, create orders, or send user notifications.
import 'dotenv/config';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { io } from 'socket.io-client';
import { Queue } from 'bullmq';

const config = JSON.parse(readFileSync('../talaDelivery-rider/config/local.json', 'utf8'));
assert.equal(config.TALA_API_KEY, process.env.APP_API_KEY);
const base = config.TALA_API_BASE_URL.replace(/\/$/, '');
const headers = { 'X-App-Key': config.TALA_API_KEY, 'Content-Type': 'application/json' };
const db = new pg.Client({ host: process.env.POSTGRES_HOST,
  port: Number(process.env.POSTGRES_PORT), user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD, database: 'taladelivery_identity' });
await db.connect();
let rider;
try {
  const users = await db.query("SELECT id,email,password FROM users WHERE role='rider' AND status='ACTIVE' AND email LIKE 'rider_%@test.com' ORDER BY id DESC LIMIT 30");
  for (const user of users.rows) {
    if (await bcrypt.compare('Rider@123456', user.password)) { rider = user; break; }
  }
} finally { await db.end(); }
assert(rider, 'Requires an existing disposable rider fixture; no new account is registered.');
async function api(path, body) {
  const response = await fetch(`${base}/${path}`, { method: body ? 'POST' : 'GET',
    headers, body: body ? JSON.stringify(body) : undefined });
  const json = await response.json();
  assert(response.ok, `${path}: ${response.status} ${json.message}`);
  return json.data;
}
const login = await api('auth/login', { email: rider.email, password: 'Rider@123456' });
assert.equal(login.user.role, 'rider');
headers.Authorization = `Bearer ${login.token}`;
const profile = await api('rider/profile');
assert.equal(profile.user.id, rider.id);
assert.equal(typeof profile.tala_coins_balance, 'string');
const before = { status: profile.status, online: profile.is_online, balance: profile.tala_coins_balance };
const offers = await api('rider/offers');
for (const offer of offers) {
  assert(offer.delivery?.id, 'Offer contains its delivery');
  assert(offer.delivery.order?.orderNumber, 'Offer contains hydrated order');
  assert(offer.delivery.store?.id, 'Offer contains hydrated store');
}
const deliveries = await api('rider/deliveries?per_page=100');
for (const delivery of deliveries.data) {
  assert(delivery.order?.orderNumber, 'Delivery order number is present');
  assert(Array.isArray(delivery.order.items), 'Delivery order checklist is present');
  assert(delivery.store?.id, 'Delivery store is present');
}
assert((await api('rider/earnings-summary')).periods.today);
assert(Array.isArray((await api('notifications?per_page=50')).data));
assert.equal((await api('auth/me')).id, rider.id);
const refreshed = await api('auth/refresh', { refresh_token: login.refresh_token });
assert(refreshed.token && refreshed.refresh_token);
headers.Authorization = `Bearer ${refreshed.token}`;
assert.equal((await api('auth/me')).id, rider.id);
console.log(`PASS: LAN rider login, JWT refresh, profile, offers, deliveries, earnings and notifications (${rider.email}).`);

const sockets = [];
function socket(token) {
  const s = io(`${config.TALA_SOCKET_URL}/realtime`, {
    auth: { token }, transports: ['websocket'], reconnection: false, autoConnect: false });
  sockets.push(s); return s;
}
async function connect(s) {
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Socket connection timed out')), 8000);
    s.once('connect', () => { clearTimeout(timer); resolve(); });
    s.once('connect_error', e => { clearTimeout(timer); reject(e); });
    s.connect();
  });
}
function subscribe(s, room) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Subscription timed out')), 8000);
    s.emit('subscribe', { room }, reply => { clearTimeout(timer); resolve(reply.data ?? reply); });
  });
}
const syntheticId = 2147483600;
const token = jwt.sign({ sub: syntheticId, email: 'rider-realtime-probe@invalid.test',
  role: 'rider', status: 'ACTIVE', type: 'access', jti: randomUUID() },
  process.env.JWT_ACCESS_SECRET, { expiresIn: '5m' });
const queue = new Queue('realtime-feed', { prefix: process.env.BULLMQ_PREFIX ?? 'bull',
  connection: { host: process.env.REDIS_HOST, port: Number(process.env.REDIS_PORT),
    password: process.env.REDIS_PASSWORD || undefined, db: Number(process.env.REDIS_DB ?? 0),
    maxRetriesPerRequest: 1 } });
try {
  const real = socket(refreshed.token); await connect(real);
  assert.equal((await subscribe(real, `user:${rider.id}`)).success, true);
  assert.equal((await subscribe(real, `user:${rider.id + 1}`)).success, false);
  assert.equal((await subscribe(real, 'admin:platform')).success, false);
  real.disconnect();
  const probe = socket(token); await connect(probe);
  assert.equal((await subscribe(probe, `user:${syntheticId}`)).success, true);
  for (const event of ['delivery.offered', 'delivery.updated', 'offer.updated', 'notification.created']) {
    const probeId = randomUUID();
    const received = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Broker event timed out: ${event}`)), 8000);
      probe.once(event, data => { clearTimeout(timer); resolve(data); });
    });
    await queue.add('event', { eventId: randomUUID(), eventType: 'realtime.emit',
      eventVersion: 1, occurredAt: new Date().toISOString(), correlationId: randomUUID(),
      data: { rooms: [`user:${syntheticId}`], event, data: { probeId } } },
      { removeOnComplete: true, removeOnFail: true });
    assert.equal((await received).probeId, probeId);
  }
  probe.disconnect(); await connect(probe);
  assert.equal((await subscribe(probe, `user:${syntheticId}`)).success, true);
  console.log('PASS: LAN Socket.IO user isolation, broker delivery/offer/notification events and reconnect.');
} finally {
  sockets.forEach(s => s.disconnect());
  await queue.close();
}
const after = await api('rider/profile');
assert.deepEqual({ status: after.status, online: after.is_online, balance: after.tala_coins_balance }, before);
assert.equal((await api('rider/deliveries?per_page=100')).meta.total, deliveries.meta.total);
console.log('PASS: Existing rider status, balance and deliveries unchanged; no orders or notifications created.');
