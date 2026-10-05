// Read-only smoke checks for the local dev services after restart.
require('dotenv').config({ quiet: true });
const assert = require('node:assert/strict');
const { Client } = require('pg');

async function main() {
  for (const port of [3001, 3004, 3005, 3007]) {
    const response = await fetch(`http://127.0.0.1:${port}/health/live`);
    assert.equal(response.status, 200, `Service ${port} must be healthy`);
  }
  const admins = await fetch('http://127.0.0.1:3001/internal/admin/active-users', {
    headers: { 'X-Service-Token': process.env.INTERNAL_API_TOKEN ?? '' },
  });
  assert.equal(admins.status, 200, 'Internal active-admin lookup must be registered');
  const adminBody = await admins.json();
  assert(Array.isArray(adminBody.data), 'Active admins must return an array');
  const denied = await fetch('http://127.0.0.1:3005/api/v1/admin/riders/1/coins', {
    headers: { 'X-App-Key': process.env.APP_API_KEY ?? '' },
  });
  assert.equal(denied.status, 401, 'Coin history must require authentication');

  for (const database of ['taladelivery_dispatch', 'taladelivery_notification']) {
    const client = new Client({ host: process.env.POSTGRES_HOST, port: Number(process.env.POSTGRES_PORT ?? 5432),
      user: process.env.POSTGRES_USER, password: process.env.POSTGRES_PASSWORD, database });
    await client.connect();
    try {
      const fields = database === 'taladelivery_dispatch'
        ? [['riders', 'tala_coins_balance'], ['delivery_zones', 'tala_coins_percent'], ['deliveries', 'tala_coins_percent'], ['deliveries', 'delivery_zone_id'], ['rider_coin_transactions', 'balance_after']]
        : [['notifications', 'source_key']];
      for (const [table, column] of fields) {
        const result = await client.query('SELECT 1 FROM information_schema.columns WHERE table_schema = $1 AND table_name = $2 AND column_name = $3', ['public', table, column]);
        assert.equal(result.rows.length, 1, `${table}.${column} must exist`);
      }
    } finally { await client.end(); }
  }
  console.log('PASS: four services healthy, active-admin endpoint available, coin history requires authentication, and new coin/notification schema is installed.');
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
