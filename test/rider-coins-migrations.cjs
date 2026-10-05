// Validate the new migrations in a temporary schema, rolled back in full.
require('dotenv').config({ quiet: true });
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('pg');
const { AddRiderTalaCoins1791158400000 } = require('../apps/dispatch-service/src/migrations/1791158400000-AddRiderTalaCoins');
const { AddNotificationSourceKey1791158400000 } = require('../apps/notification-service/src/migrations/1791158400000-AddNotificationSourceKey');

async function main() {
  const host = process.env.POSTGRES_HOST ?? 'localhost';
  assert(['localhost', '127.0.0.1', '::1'].includes(host), 'This test only runs against a local PostgreSQL instance.');
  const client = new Client({ host, port: Number(process.env.POSTGRES_PORT ?? 5432),
    user: process.env.POSTGRES_USER, password: process.env.POSTGRES_PASSWORD,
    database: 'taladelivery_dispatch', connectionTimeoutMillis: 3000 });
  const schema = `coin_test_${randomUUID().replaceAll('-', '')}`;
  await client.connect();
  try {
    await client.query('BEGIN');
    await client.query(`CREATE SCHEMA ${schema}`);
    await client.query(`SET LOCAL search_path TO ${schema}`);
    await client.query('CREATE TABLE riders (id SERIAL PRIMARY KEY)');
    await client.query('CREATE TABLE deliveries (id SERIAL PRIMARY KEY)');
    await client.query('CREATE TABLE delivery_zones (id SERIAL PRIMARY KEY)');
    await client.query('CREATE TABLE notifications (id SERIAL PRIMARY KEY)');
    const runner = { query: async (sql) => (await client.query(sql)).rows };
    const coins = new AddRiderTalaCoins1791158400000();
    const notifications = new AddNotificationSourceKey1791158400000();
    await coins.up(runner);
    await notifications.up(runner);
    await client.query('INSERT INTO riders DEFAULT VALUES');
    await client.query('INSERT INTO deliveries DEFAULT VALUES');
    await client.query('INSERT INTO delivery_zones DEFAULT VALUES');
    assert.equal((await client.query('SELECT tala_coins_balance FROM riders')).rows[0].tala_coins_balance, '0.00');
    assert.equal((await client.query('SELECT tala_coins_percent FROM delivery_zones')).rows[0].tala_coins_percent, '0.00');
    await client.query("UPDATE riders SET tala_coins_balance = -5.00 WHERE id = 1");
    await client.query("INSERT INTO rider_coin_transactions (rider_id, delivery_id, type, amount, balance_after, deduction_percent, admin_alert_pending) VALUES (1,1,'DELIVERY_DEDUCTION',-10.00,-5.00,10.00,true)");
    await client.query('SAVEPOINT duplicate_delivery');
    try {
      await client.query("INSERT INTO rider_coin_transactions (rider_id, delivery_id, type, amount, balance_after) VALUES (1,1,'DELIVERY_DEDUCTION',-10.00,-15.00)");
      assert.fail('Duplicate delivery must be rejected');
    } catch (error) { assert.equal(error.code, '23505'); }
    await client.query('ROLLBACK TO SAVEPOINT duplicate_delivery');
    await client.query('SAVEPOINT percent_range');
    try { await client.query('UPDATE delivery_zones SET tala_coins_percent = 101'); assert.fail('Invalid percentage must be rejected'); }
    catch (error) { assert.equal(error.code, '23514'); }
    await client.query('ROLLBACK TO SAVEPOINT percent_range');
    await client.query("INSERT INTO notifications (source_key) VALUES ('rider-coins:1:1') ON CONFLICT DO NOTHING");
    await client.query("INSERT INTO notifications (source_key) VALUES ('rider-coins:1:1') ON CONFLICT DO NOTHING");
    assert.equal((await client.query('SELECT count(*)::int AS count FROM notifications')).rows[0].count, 1);
    await notifications.down(runner);
    await coins.down(runner);
    console.log('PASS: PostgreSQL migration up/down, zero defaults, negative balance, percentage range, unique delivery deductions and notification deduplication.');
  } finally {
    await client.query('ROLLBACK');
    await client.end();
  }
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
