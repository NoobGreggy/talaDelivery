import { IsIn, IsString, IsUrl } from 'class-validator';

/**
 * API-gateway environment schema (validated once at boot by
 * `createEnvValidator` via ConfigModule).
 */
export class GatewayEnvironmentVariables {
  @IsString()
  NODE_ENV: string = 'development';

  @IsIn(['trace', 'debug', 'info', 'warn', 'error', 'fatal'])
  LOG_LEVEL: string = 'info';

  @IsString()
  SERVICE_NAME: string = 'api-gateway';

  /** Injected as `X-App-Key` on every proxied request (§5 gateway proxying). */
  @IsString()
  APP_API_KEY: string = 'change-me-dev-api-key';

  @IsUrl({ require_tld: false })
  IDENTITY_SERVICE_URL: string = 'http://localhost:3001';

  @IsUrl({ require_tld: false })
  MERCHANT_SERVICE_URL: string = 'http://localhost:3002';

  @IsUrl({ require_tld: false })
  CATALOG_SERVICE_URL: string = 'http://localhost:3003';

  @IsUrl({ require_tld: false })
  ORDER_SERVICE_URL: string = 'http://localhost:3004';

  @IsUrl({ require_tld: false })
  DISPATCH_SERVICE_URL: string = 'http://localhost:3005';

  @IsUrl({ require_tld: false })
  PAYMENT_SERVICE_URL: string = 'http://localhost:3006';

  @IsUrl({ require_tld: false })
  NOTIFICATION_SERVICE_URL: string = 'http://localhost:3007';

  @IsUrl({ require_tld: false })
  REALTIME_SERVICE_URL: string = 'http://localhost:3008';
}