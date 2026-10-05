import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { createEnvValidator, HealthController } from '@taladelivery/common';
import { GatewayEnvironmentVariables } from './config/env';

/**
 * API gateway module.
 *
 * The gateway is deliberately minimal: a thin prefix-based proxy plus the
 * shared health controller. It has no database, no service-specific business
 * logic, and no events — those belong to the owning services (§20.8).
 */
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(GatewayEnvironmentVariables),
      envFilePath: ['.env.local', '.env'],
    }),
  ],
  controllers: [HealthController],
})
export class AppModule {}