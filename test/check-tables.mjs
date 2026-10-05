import 'dotenv/config';
import pg from 'pg';

const { Client } = pg;

const client = new Client({
  host: process.env.POSTGRES_HOST,
  port: Number.parseInt(process.env.POSTGRES_PORT, 10),
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: 'taladelivery_dispatch',
});

await client.connect();
const result = await client.query(
  "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name",
);
console.log('Dispatch DB tables:', result.rows.map((r) => r.table_name).join(', '));
await client.end();
