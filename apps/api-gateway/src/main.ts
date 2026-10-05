import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { bootstrapLogger, configureHttpApp, resolvePort } from '@taladelivery/common';
import { AppModule } from './app.module';
import { gatewayProxyMiddleware } from './gateway-proxy.middleware';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  // No global prefix here: services already mount their public paths at
  // /api/v1 and the gateway forwards the full original path (§5 gateway proxying).
  configureHttpApp(app, {
    title: 'TalaDelivery API Gateway',
    description:
      'Public entry point: thin prefix-based proxy to TalaDelivery microservices (Phases 1-11).',
    version: '1.0',
  });

  // Register the raw proxy middleware BEFORE `app.init()`.
  //
  // Express dispatches in registration order, and `app.init()` is what mounts
  // the Nest router. Registering the proxy afterwards means the router sees
  // every request first, answers 404 for the whole API, and the proxy never
  // runs. Mounted here, the proxy runs first and calls `next()` only for the
  // gateway's own paths (/health, /docs, /).
  app.getHttpAdapter().getInstance().use(gatewayProxyMiddleware);

  await app.init();

  const port = resolvePort(3000);
  await app.listen(port);
  bootstrapLogger().log(`api-gateway listening on http://localhost:${port}`);
}

void bootstrap().catch((error: unknown) => {
  new Logger('Bootstrap').error('api-gateway failed to start', error as Error);
  process.exit(1);
});