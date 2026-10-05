import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { bootstrapLogger, configureHttpApp, resolvePort } from '@taladelivery/common';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  configureHttpApp(app, {
    title: 'TalaDelivery Notification Service',
    description: 'Notification ownership and delivery.',
    version: '1.0',
    prefix: 'api/v1',
    prefixExclude: ['internal/{*path}', 'health/{*path}'],
  });
  const port = resolvePort(3007);
  await app.listen(port);
  bootstrapLogger().log(`notification-service listening on http://localhost:${port}`);
}

void bootstrap().catch((error: unknown) => {
  new Logger('Bootstrap').error('notification-service failed to start', error as Error);
  process.exit(1);
});
