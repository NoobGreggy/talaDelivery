import 'dotenv/config';
import pg from 'pg';

const { Client } = pg;

async function seedZone() {
  const client = new Client({
    host: process.env.POSTGRES_HOST ?? 'localhost',
    port: Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10),
    user: process.env.POSTGRES_USER ?? 'postgres',
    password: process.env.POSTGRES_PASSWORD ?? '',
    database: 'taladelivery_dispatch',
  });

  await client.connect();

  const existing = await client.query(
    "SELECT id FROM delivery_zones WHERE city = 'Makati City' AND province = 'Metro Manila' AND status = 'ACTIVE' LIMIT 1"
  );

  if (existing.rows.length > 0) {
    console.log(`Zone already exists (id: ${existing.rows[0].id})`);
    await client.end();
    return;
  }

  const result = await client.query(
    `INSERT INTO delivery_zones (name, city, province, base_fee, included_km, extra_fee_per_km, maximum_delivery_km, maximum_delivery_fee, distance_rounding_km, boundary_geojson, status, effective_from, created_at, updated_at)
     VALUES ('Makati Zone', 'Makati City', 'Metro Manila', '49.00', '3.00', '10.00', NULL, NULL, '0.10', NULL, 'ACTIVE', NULL, NOW(), NOW())
     RETURNING id, name, city, province`
  );

  console.log('Zone created:', JSON.stringify(result.rows[0], null, 2));
  await client.end();
}

seedZone().catch((error) => {
  console.error('Failed to seed zone:', error);
  process.exit(1);
});
