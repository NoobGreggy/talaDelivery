import { DataSource } from 'typeorm';
import { PAYMENT_DB_NAME } from './env';

/**
 * Data source used by the TypeORM CLI (`npm run migration:run:payment`) and
 * kept in sync with the runtime options in app.module.ts.
 *
 * Schema creation in development uses `synchronize` at runtime (see
 * app.module.ts). Production deployments switch to structured migrations.
 */
export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.POSTGRES_HOST ?? 'localhost',
  port: Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10),
  username: process.env.POSTGRES_USER ?? 'tala',
  password: process.env.POSTGRES_PASSWORD ?? '',
  database: process.env.POSTGRES_DB_NAME ?? PAYMENT_DB_NAME,
  ssl: process.env.POSTGRES_SSL === 'true' ? { rejectUnauthorized: false } : false,
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/migrations/*{.ts,.js}'],
  synchronize: false,
  logging: false,
});