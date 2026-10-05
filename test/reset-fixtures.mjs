/**
 * Resets E2E fixtures so the flow tests are repeatable.
 *
 * Order creation decrements product stock, so a handful of runs exhausts the
 * seeded inventory and every later run fails with "Insufficient stock" — which
 * looks like a product bug rather than a test-data problem. This restores
 * stock to a high value and clears stale offers.
 *
 *   node test/reset-fixtures.mjs
 */
import 'dotenv/config';
import pg from 'pg';

const { Client } = pg;

function connect(database) {
  return new Client({
    host: process.env.POSTGRES_HOST,
    port: Number.parseInt(process.env.POSTGRES_PORT, 10),
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database,
  });
}

const catalog = connect('taladelivery_catalog');
await catalog.connect();
const products = await catalog.query(
  "UPDATE products SET stock = 1000 WHERE id = 1 RETURNING id, name, stock",
);
console.log(
  'Catalog:',
  products.rows.length > 0
    ? products.rows.map((p) => `${p.name} (id ${p.id}) stock=${p.stock}`).join(', ')
    : 'product 1 not found — run test/seed-test-data.mjs',
);
await catalog.end();

const dispatch = connect('taladelivery_dispatch');
await dispatch.connect();
// Offers left PENDING by a previous aborted run would be picked up by the
// next run's matching query and mask the new order's offer.
const offers = await dispatch.query(
  "UPDATE delivery_offers SET status = 'EXPIRED' WHERE status = 'PENDING' RETURNING id",
);
console.log(`Dispatch: expired ${offers.rowCount} stale pending offer(s)`);
const riders = await dispatch.query(
  "UPDATE riders SET status = 'OFFLINE', is_online = false WHERE status <> 'PENDING' RETURNING id",
);
console.log(`Dispatch: set ${riders.rowCount} rider(s) offline`);
await dispatch.end();

console.log('Fixtures reset.');
