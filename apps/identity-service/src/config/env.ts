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
 * Identity-service environment schema (validated once at boot).
 * The TypeORM CLI (`typeorm-ts-node-commonjs`) and the app share these values.
 */
export class IdentityEnvironmentVariables {
  @IsString()
  NODE_ENV: string = 'development';

  @IsIn(['trace', 'debug', 'info', 'warn', 'error', 'fatal'])
  LOG_LEVEL: string = 'info';

  @IsString()
  SERVICE_NAME: string = 'identity-service';

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
  JWT_ALGORITHM: string = 'HS256';

  @IsString()
  JWT_ACCESS_SECRET: string = 'dev-access-secret';

  @IsString()
  JWT_ACCESS_TTL: string = '15m';

  @IsString()
  JWT_REFRESH_SECRET: string = 'dev-refresh-secret';

  @IsString()
  JWT_REFRESH_TTL: string = '30d';

  @IsOptional()
  @IsString()
  DISPATCH_SERVICE_URL: string | undefined;

  // Needed by EventsModule (rider applications alert platform admins).
  @IsOptional()
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

  @IsOptional()
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
}

/** Default database name when POSTGRES_DB_NAME is not provided. */
export const IDENTITY_DB_NAME = 'taladelivery_identity';