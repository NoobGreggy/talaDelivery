import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { bootstrapLogger, configureHttpApp, resolvePort } from '@taladelivery/common';
import { AppModule } from './app.module';
import { json } from 'express';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  // A 5 MiB file expands to ~6.67 MiB as Base64. Scope the larger JSON limit
  // to product upload routes; other endpoints keep their normal limits.
  app.use('/api/v1/store/products', json({ limit: '8mb' }));
  app.use('/api/v1/merchant/products', json({ limit: '8mb' }));
  // Nest detects the scoped jsonParser above and skips its global JSON parser.
  // Explicitly parse all remaining routes, including category creation.
  app.use(json({ limit: '100kb' }));
  configureHttpApp(app, {
    title: 'TalaDelivery Catalog Service',
    description: 'Product and category ownership.',
    version: '1.0',
    prefix: 'api/v1',
    prefixExclude: ['internal/{*path}', 'health/{*path}'],
  });
  const port = resolvePort(3003);
  await app.listen(port);
  bootstrapLogger().log(`catalog-service listening on http://localhost:${port}`);
}

void bootstrap().catch((error: unknown) => {
  new Logger('Bootstrap').error('catalog-service failed to start', error as Error);
  process.exit(1);
});
