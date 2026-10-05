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
 * Payment-service environment schema (validated once at boot).
 * The TypeORM CLI (`typeorm-ts-node-commonjs`) and the app share these values.
 */
export class PaymentEnvironmentVariables {
  @IsString()
  NODE_ENV: string = 'development';

  @IsIn(['trace', 'debug', 'info', 'warn', 'error', 'fatal'])
  LOG_LEVEL: string = 'info';

  @IsString()
  SERVICE_NAME: string = 'payment-service';

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
}

/** Default database name when POSTGRES_DB_NAME is not provided. */
export const PAYMENT_DB_NAME = 'taladelivery_payment';