import { Type } from 'class-transformer';
import {
  IsBooleanString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class RealtimeEnvironmentVariables {
  @IsOptional()
  @IsString()
  ORDER_SERVICE_URL: string | undefined;
  @IsOptional()
  @IsString()
  DISPATCH_SERVICE_URL: string | undefined;
  @IsOptional()
  @IsString()
  MERCHANT_SERVICE_URL: string | undefined;
  @IsString()
  NODE_ENV: string = 'development';

  @IsIn(['trace', 'debug', 'info', 'warn', 'error', 'fatal'])
  LOG_LEVEL: string = 'info';

  @IsString()
  SERVICE_NAME: string = 'realtime-service';

  @IsString()
  APP_API_KEY: string = 'change-me-dev-api-key';

  @IsString()
  INTERNAL_API_TOKEN: string = 'change-me-internal-token';

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

  // TokenService.verifyAccess() reads these; `JWT_SECRET` was previously
  // declared here but read by nothing, so socket auth had no configured key.
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
  @IsBooleanString()
  CORS_ENABLED: string = 'true';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  EVENTS_PUBLISH_TIMEOUT_MS: number | undefined;

  @IsOptional()
  @IsBooleanString()
  EVENTS_FAIL_SOFT: string | undefined;
}
