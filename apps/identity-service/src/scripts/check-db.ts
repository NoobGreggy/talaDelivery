import 'dotenv/config';
import { AppDataSource } from '../config/data-source';

async function checkDb(): Promise<void> {
  await AppDataSource.initialize();

  const migrations = await AppDataSource.query('SELECT * FROM migrations ORDER BY id DESC');
  console.log('Migrations:', JSON.stringify(migrations, null, 2));

  const tables = await AppDataSource.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name",
  );
  console.log('Tables:', JSON.stringify(tables));

  await AppDataSource.destroy();
}

checkDb().catch((error) => {
  console.error('Failed:', error);
  process.exit(1);
});
