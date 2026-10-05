import 'dotenv/config';
import pg from 'pg';

const { Client } = pg;

const dbs = [
  'taladelivery_identity',
  'taladelivery_merchant',
  'taladelivery_catalog',
  'taladelivery_order',
  'taladelivery_dispatch',
  'taladelivery_payment',
  'taladelivery_notification',
  'taladelivery_realtime',
];

const admin = new Client({
  host: process.env.POSTGRES_HOST,
  port: Number.parseInt(process.env.POSTGRES_PORT, 10),
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: 'postgres',
});
await admin.connect();

const existing = new Set(
  (await admin.query("SELECT datname FROM pg_database WHERE datname LIKE 'taladelivery%'")).rows.map(
    (r) => r.datname,
  ),
);

for (const db of dbs) {
  if (existing.has(db)) {
    console.log(`exists   ${db}`);
  } else {
    // CREATE DATABASE cannot be parameterised; the name comes from this
    // fixed list, never from input.
    await admin.query(`CREATE DATABASE ${db}`);
    console.log(`created  ${db}`);
  }
}

await admin.end();
