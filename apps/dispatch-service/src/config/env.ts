import { Type } from 'class-transformer';
import {
  IsBooleanString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

/**
 * Dispatch-service environment schema (validated once at boot).
 * The TypeORM CLI (`typeorm-ts-node-commonjs`) and the app share these values.
 */
export class DispatchEnvironmentVariables {
  @IsString()
  NODE_ENV: string = 'development';

  @IsIn(['trace', 'debug', 'info', 'warn', 'error', 'fatal'])
  LOG_LEVEL: string = 'info';

  @IsString()
  SERVICE_NAME: string = 'dispatch-service';

  @IsString()
  APP_API_KEY: string = 'change-me-dev-api-key';

  @IsString()
  INTERNAL_API_TOKEN: string = 'change-me-internal-token';

  @IsString()
  POSTGRES_HOST: string = 'localhost';

  @Type(() => Number)
  @IsInt()
  @Min(1)
  POSTGRES_PORT: number = 5432;

  @IsString()
  POSTGRES_USER: string = 'tala';

  @IsString()
  POSTGRES_PASSWORD: string = '';

  @IsOptional()
  @IsString()
  POSTGRES_DB_NAME: string | undefined;

  @IsOptional()
  @IsBooleanString()
  POSTGRES_SSL: string = 'false';

  @IsString()
  REDIS_HOST: string = 'localhost';

  @Type(() => Number)
  @IsInt()
  @Min(1)
  REDIS_PORT: number = 6379;

  @IsOptional()
  @IsString()
  REDIS_PASSWORD: string | undefined;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  REDIS_DB: number = 0;

  @IsString()
  BULLMQ_PREFIX: string = 'bull';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  EVENTS_PUBLISH_TIMEOUT_MS: number | undefined;

  @IsOptional()
  @IsBooleanString()
  EVENTS_FAIL_SOFT: string | undefined;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  OFFER_TTL_SECONDS: number = 300;

  @IsString()
  GEOCODING_BASE_URL: string = '';

  @IsString()
  GEOCODING_USER_AGENT: string = 'taladelivery-backend';

  @Type(() => Number)
  @IsInt()
  GEOCODING_CACHE_DAYS: number = 30;

  @IsString()
  ROUTING_BASE_URL: string = '';

  @Type(() => Number)
  @IsInt()
  ROUTING_CONNECT_TIMEOUT_MS: number = 2000;

  @Type(() => Number)
  @IsInt()
  ROUTING_TIMEOUT_MS: number = 5000;

  @IsOptional()
  @IsString()
  IDENTITY_SERVICE_URL: string | undefined;

  @IsOptional()
  @IsString()
  JWT_ACCESS_SECRET: string | undefined;

  @IsOptional()
  @IsString()
  JWT_REFRESH_SECRET: string | undefined;

  @IsOptional()
  @IsString()
  JWT_ACCESS_TTL: string = '15m';

  @IsOptional()
  @IsString()
  JWT_REFRESH_TTL: string = '30d';

  @IsOptional()
  @IsString()
  ORDER_SERVICE_URL: string | undefined;

  @IsOptional()
  @IsString()
  MERCHANT_SERVICE_URL: string | undefined;
}

/** Default database name when POSTGRES_DB_NAME is not provided. */
export const DISPATCH_DB_NAME = 'taladelivery_dispatch';