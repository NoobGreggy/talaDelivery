import { Module } from '@nestjs/common';
import { CustomerAddress } from './entities/customer-address.entity';
import { AddressesController } from './controllers/addresses.controller';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { createEnvValidator, HealthController, ServiceClientFactory } from '@taladelivery/common';
import { AuthModule, TokenService } from '@taladelivery/auth';
import { EventsModule } from '@taladelivery/events';
import { IdentityEnvironmentVariables, IDENTITY_DB_NAME } from './config/env';
import { User } from './entities/user.entity';
import { RefreshToken } from './entities/refresh-token.entity';

import { TokenGateway } from './services/token-gateway';
import { UserService } from './services/user.service';
import { UserResourcesService } from './services/user-resources.service';
import { AuthService } from './services/auth.service';
import { RiderRegistrationService } from './services/rider-registration.service';

import { AuthController } from './controllers/auth.controller';
import { RiderRegisterController } from './controllers/rider-register.controller';
import { AdminCustomerController } from './controllers/admin/admin-customer.controller';
import { AdminUserController } from './controllers/admin/admin-user.controller';
import { IdentityInternalController } from './controllers/internal/internal.controller';

const ENTITIES = [User, RefreshToken, CustomerAddress];

const SERVICES = [
  UserService,
  UserResourcesService,
  AuthService,
  RiderRegistrationService,
  ServiceClientFactory,
  // `@nestjs/jwt`-backed TokenService satisfies the local TokenGateway
  // contract at runtime while keeping the ESM package out of unit tests.
  { provide: TokenGateway, useExisting: TokenService },
];

const CONTROLLERS = [
  AddressesController,
  HealthController,
  AuthController,
  RiderRegisterController,
  AdminCustomerController,
  AdminUserController,
  IdentityInternalController,
];

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(IdentityEnvironmentVariables),
      envFilePath: ['.env.local', '.env'],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres' as const,
        host: config.get<string>('POSTGRES_HOST', 'localhost'),
        port: config.get<number>('POSTGRES_PORT', 5432),
        username: config.get<string>('POSTGRES_USER', 'tala'),
        password: config.get<string>('POSTGRES_PASSWORD', ''),
        database: config.get<string>('POSTGRES_DB_NAME') ?? IDENTITY_DB_NAME,
        ssl:
          config.get<string>('POSTGRES_SSL') === 'true'
            ? { rejectUnauthorized: false }
            : false,
        autoLoadEntities: true,
        // Dev convenience; production uses structured migrations (Phase 19).
        synchronize: config.get<string>('NODE_ENV') !== 'production',
        logging: false,
      }),
    }),
    TypeOrmModule.forFeature(ENTITIES),
    AuthModule,
    // identity publishes (never consumes) notification + realtime events when a
    // rider application arrives.
    EventsModule.forRoot(),
  ],
  controllers: CONTROLLERS,
  providers: SERVICES,
})
export class AppModule {}
