import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { bootstrapLogger, configureHttpApp, resolvePort } from '@taladelivery/common';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  configureHttpApp(app, {
    title: 'TalaDelivery Identity Service',
    description:
      'Authentication, profiles and customer/rider identity (Phases 2-4, 8).',
    version: '1.0',
    prefix: 'api/v1',
    prefixExclude: ['internal/{*path}', 'health/{*path}'],
  });

  const port = resolvePort(3001);
  await app.listen(port);
  bootstrapLogger().log(`identity-service listening on http://localhost:${port}`);
}

void bootstrap().catch((error: unknown) => {
  new Logger('Bootstrap').error('identity-service failed to start', error as Error);
  process.exit(1);
});
