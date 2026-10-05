import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { bootstrapLogger, configureHttpApp, resolvePort } from '@taladelivery/common';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  configureHttpApp(app, {
    title: 'TalaDelivery Realtime Service',
    description: 'WebSocket realtime communication.',
    version: '1.0',
    prefix: 'api/v1',
    prefixExclude: ['internal/{*path}', 'health/{*path}'],
  });
  const port = resolvePort(3008);
  await app.listen(port);
  bootstrapLogger().log(`realtime-service listening on http://localhost:${port}`);
}

void bootstrap().catch((error: unknown) => {
  new Logger('Bootstrap').error('realtime-service failed to start', error as Error);
  process.exit(1);
});
