// Read-only customer ownership checks and an isolated broker probe. No real
// rider coordinates, orders, coins, availability or notifications are changed.
import 'dotenv/config';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
import jwt from 'jsonwebtoken';
import { io } from 'socket.io-client';
import { Queue } from 'bullmq';

const config = JSON.parse(readFileSync('../talaDelivery-rider/config/local.json', 'utf8'));
const db = new pg.Client({ host: process.env.POSTGRES_HOST, port: Number(process.env.POSTGRES_PORT),
  user: process.env.POSTGRES_USER, password: process.env.POSTGRES_PASSWORD, database: 'taladelivery_order' });
await db.connect();
let order;
try { order = (await db.query('SELECT id,customer_id,delivery_id FROM orders WHERE delivery_id IS NOT NULL ORDER BY id DESC LIMIT 1')).rows[0]; }
finally { await db.end(); }
assert(order, 'An existing order with a delivery is required; this test does not create one.');
function token(sub, role = 'customer') {
  return jwt.sign({ sub, role, email: 'tracking-probe@invalid.test', status: 'ACTIVE', type: 'access', jti: randomUUID() },
    process.env.JWT_ACCESS_SECRET, { expiresIn: '5m' });
}
async function get(userId) {
  const response = await fetch(`${config.TALA_API_BASE_URL.replace(/\/$/, '')}/orders/${order.id}`, {
    headers: { 'X-App-Key': config.TALA_API_KEY, Authorization: `Bearer ${token(userId)}` },
  });
  return { response, json: await response.json() };
}
const owned = await get(order.customer_id);
assert.equal(owned.response.status, 200);
assert.equal(owned.json.data.delivery.id, order.delivery_id);
assert(Object.hasOwn(owned.json.data.delivery, 'rider_location'));
assert(Object.hasOwn(owned.json.data.delivery, 'delivery_latitude'));
assert.equal((await get(order.customer_id + 1)).response.status, 404);
console.log('PASS: Customer order contains the delivery tracking snapshot; another customer cannot read it.');

const sockets = [];
async function connect(access) {
  const s = io(`${config.TALA_SOCKET_URL}/realtime`, { auth: { token: access }, transports: ['websocket'], reconnection: false, autoConnect: false });
  sockets.push(s);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Socket connect timeout')), 10000);
    s.once('connect', () => { clearTimeout(timer); resolve(); });
    s.once('connect_error', () => { clearTimeout(timer); reject(new Error('Socket rejected')); });
    s.connect();
  });
  return s;
}
function ack(s, event, body) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Socket acknowledgment timeout')), 10000);
    s.emit(event, body, reply => { clearTimeout(timer); resolve(reply.data ?? reply); });
  });
}
const unusedDelivery = 2147483590, unusedOrder = 2147483591, unusedRider = 2147483592;
const queue = new Queue('location-events', { prefix: process.env.BULLMQ_PREFIX ?? 'bull', connection: {
  host: process.env.REDIS_HOST, port: Number(process.env.REDIS_PORT), password: process.env.REDIS_PASSWORD || undefined,
  db: Number(process.env.REDIS_DB ?? 0), maxRetriesPerRequest: 1,
} });
try {
  const customer = await connect(token(order.customer_id));
  assert.equal((await ack(customer, 'subscribe', { room: `delivery:${order.delivery_id}` })).success, true);
  const stranger = await connect(token(order.customer_id + 1));
  assert.equal((await ack(stranger, 'subscribe', { room: `delivery:${order.delivery_id}` })).success, false);
  assert.equal((await ack(customer, 'location:update', { deliveryId: order.delivery_id, latitude: 0, longitude: 0 })).success, false);
  customer.disconnect(); stranger.disconnect();
  const probe = await connect(token(2147483580, 'platform_admin'));
  assert.equal((await ack(probe, 'subscribe', { room: `delivery:${unusedDelivery}` })).success, true);
  const timestamp = new Date().toISOString();
  const received = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Location broker timeout')), 10000);
    probe.once('rider.location', body => { clearTimeout(timer); resolve(body); });
  });
  await queue.add('event', { eventId: randomUUID(), eventType: 'rider.location.updated', eventVersion: 1,
    occurredAt: timestamp, correlationId: randomUUID(), data: { deliveryId: unusedDelivery,
      orderId: unusedOrder, riderId: unusedRider, latitude: '16.9452', longitude: '121.7662',
      accuracyM: 7, headingDeg: 90, speedMps: 5, recordedAt: timestamp } },
    { removeOnComplete: true, removeOnFail: true });
  const payload = await received;
  assert.equal(payload.deliveryId, unusedDelivery);
  assert.equal(payload.orderId, unusedOrder);
  assert.equal(payload.timestamp, timestamp);
  assert.equal(payload.latitude, 16.9452);
  console.log('PASS: Owned delivery-room authorization, socket spoofing rejection, and location queue → Socket.IO delivery event.');
  console.log('PASS: Broker coordinates targeted unused synthetic IDs only; no real delivery data changed.');
} finally {
  sockets.forEach(s => s.disconnect());
  await queue.close();
}
