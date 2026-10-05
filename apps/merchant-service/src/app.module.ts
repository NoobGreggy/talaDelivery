import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '@taladelivery/auth';
import { createEnvValidator, HealthController, ServiceClientFactory } from '@taladelivery/common';
import { EventsModule } from '@taladelivery/events';
import { MERCHANT_DB_NAME, MerchantEnvironmentVariables } from './config/env';
import { Store } from './entities/store.entity';
import { StoreUser } from './entities/store-user.entity';
import { StoresController } from './controllers/stores.controller';
import { StoreProfileController } from './controllers/store-profile.controller';
import { AdminStoreController } from './controllers/admin/admin-store.controller';
import { MerchantInternalController } from './controllers/internal/internal.controller';
import { OrderEventsConsumer } from './consumers/order-events.consumer';
import { StoreService } from './services/store.service';
import { StoreCategory } from './entities/store-category.entity';
import { StoreCategoryService } from './services/store-category.service';
import { StoreDeliveryZonesService } from './services/store-delivery-zones.service';
import { AdminStoreCategoryController, StoreCategoryController } from './controllers/admin/store-category.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: createEnvValidator(MerchantEnvironmentVariables), envFilePath: ['.env.local', '.env'] }),
    TypeOrmModule.forRootAsync({ inject: [ConfigService], useFactory: (config: ConfigService) => ({
      type: 'postgres' as const, host: config.get<string>('POSTGRES_HOST', 'localhost'), port: config.get<number>('POSTGRES_PORT', 5432),
      username: config.get<string>('POSTGRES_USER', 'tala'), password: config.get<string>('POSTGRES_PASSWORD', ''), database: config.get<string>('POSTGRES_DB_NAME') ?? MERCHANT_DB_NAME,
      ssl: config.get<string>('POSTGRES_SSL') === 'true' ? { rejectUnauthorized: false } : false, autoLoadEntities: true,
      synchronize: config.get<string>('NODE_ENV') !== 'production', logging: false,
    }) }),
    TypeOrmModule.forFeature([Store, StoreUser, StoreCategory]), AuthModule,
    // Sole consumer of `merchant-jobs` (see OrderEventsConsumer).
    EventsModule.forRoot(),
  ],
  controllers: [HealthController, StoresController, StoreProfileController, AdminStoreController, AdminStoreCategoryController, StoreCategoryController, MerchantInternalController], providers: [StoreService, StoreCategoryService, StoreDeliveryZonesService, ServiceClientFactory, OrderEventsConsumer],
})
export class AppModule {}
