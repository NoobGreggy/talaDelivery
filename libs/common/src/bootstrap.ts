import {
  INestApplication,
  Logger,
  ValidationPipe,
} from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { RequestContextMiddleware } from './request-context';
import { ResponseEnvelopeInterceptor } from './response';
import { laravelValidationPipe } from './validation';
import { AppExceptionFilter } from './exception-filter';

export interface BootstrapOptions {
  title: string;
  description?: string;
  version?: string;
  /** Path prefix, e.g. 'api/v1' (Laravel compatibility). Leave empty for none. */
  prefix?: string;
  /**
   * Route patterns excluded from the global prefix (path-to-regexp).
   * Internal endpoints and health probes bypass the public prefix,
   * e.g. ['internal/{*path}', 'health/{*path}']. This is the named wildcard
   * syntax required by path-to-regexp v8 (NestJS 12).
   */
  prefixExclude?: string[];
  /** Expose Swagger UI when not in production. */
  swagger?: boolean;
  corsOrigins?: string[] | true;
}

/**
 * Applies the cross-cutting HTTP concerns shared by every TalaDelivery
 * service:
 *   - helmet + CORS + trust proxy
 *   - request-context middleware (requestId, correlationId, x-user-* adoption)
 *   - structured HTTP request logging
 *   - Laravel-shaped 422 validation pipe
 *   - { success, message, data } response envelope interceptor
 *   - exception filter that never leaks internals
 *   - graceful shutdown hooks + /health endpoints
 */
export function configureHttpApp(app: INestApplication, options: BootstrapOptions): void {
  app.use(helmet());
  app.enableCors({
    origin: options.corsOrigins ?? ['http://localhost:3000'],
    credentials: true,
  });
  app.getHttpAdapter().getInstance().set('trust proxy', 1);

  if (options.prefix) {
    app.setGlobalPrefix(
      options.prefix,
      options.prefixExclude && options.prefixExclude.length > 0 // eslint-disable-line @typescript-eslint/no-unnecessary-condition
        ? { exclude: options.prefixExclude }
        : undefined,
    );
  }

  // Request context must be outermost so logging + interceptors can read it.
  app.use(new RequestContextMiddleware().use.bind(new RequestContextMiddleware()));

  app.useGlobalPipes(laravelValidationPipe());
  app.useGlobalInterceptors(new ResponseEnvelopeInterceptor());
  app.useGlobalFilters(new AppExceptionFilter());

  if (options.swagger ?? process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle(options.title)
      .setDescription(options.description ?? '')
      .setVersion(options.version ?? '1.0')
      .addApiKey({ type: 'apiKey', name: 'X-App-Key', in: 'header' })
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, document);
  }

  app.enableShutdownHooks();
}

/** Standard Logger alias used by bootstraps. */
export function bootstrapLogger(): Logger {
  return new Logger('Bootstrap');
}

/** Resolve the HTTP port from env with a default. */
export function resolvePort(defaultPort = 3000): number {
  const raw = process.env.PORT;
  const parsed = raw === undefined ? NaN : Number.parseInt(raw, 10);
  return Number.isNaN(parsed) ? defaultPort : parsed;
}
