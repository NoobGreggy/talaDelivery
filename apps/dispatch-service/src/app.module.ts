import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  createEnvValidator,
  HealthController,
  ServiceClientFactory,
} from '@taladelivery/common';
import { AuthModule } from '@taladelivery/auth';
import { EventsModule } from '@taladelivery/events';
import { DispatchEnvironmentVariables, DISPATCH_DB_NAME } from './config/env';
import { Delivery } from './entities/delivery.entity';
import { DeliveryOffer } from './entities/delivery-offer.entity';
import { DeliveryZone } from './entities/delivery-zone.entity';
import { DeliveryZoneRevision } from './entities/delivery-zone-revision.entity';
import { DispatchSetting } from './entities/dispatch-setting.entity';
import { Rider } from './entities/rider.entity';
import { RiderCoinTransaction } from './entities/rider-coin-transaction.entity';
import { RiderCoinsService } from './services/rider-coins.service';

import { DispatchSettingsService } from './services/dispatch-settings.service';
import { RoadDistanceService } from './services/road-distance.service';
import { ZoneBoundaryService } from './services/zone-boundary.service';
import { DeliveryZoneManager } from './services/delivery-zone-manager.service';
import { PricingService } from './services/pricing.service';
import { RiderCommissionService } from './services/rider-commission.service';
import { RiderEarningsService } from './services/rider-earnings.service';
import { PlaceBoundarySearchService } from './services/place-boundary-search.service';
import { RiderMatchingService } from './services/rider-matching.service';
import { OfferExpiryScheduler } from './services/offer-expiry-scheduler.service';
import { DeliveryService } from './services/delivery.service';
import { RiderService } from './services/rider.service';
import { RemoteReferencesService } from './services/remote-references.service';
import { DispatchResourcesService } from './services/dispatch-resources.service';

import { OrderEventsConsumer } from './consumers/order-events.consumer';
import { OfferExpiryConsumer } from './consumers/offer-expiry.consumer';

import { RiderController } from './controllers/rider.controller';
import { RiderOfferController } from './controllers/rider-offer.controller';
import { RiderDeliveryController } from './controllers/rider-delivery.controller';
import { DispatchInternalController } from './controllers/internal/internal.controller';
import { InternalDeliveryZonesController } from './controllers/internal/delivery-zones.controller';
import { AdminDeliveryZonePricingPreviewController } from './controllers/admin/admin-delivery-zone-pricing-preview.controller';
import { AdminDeliveryController } from './controllers/admin/admin-delivery.controller';
import { AdminRiderController } from './controllers/admin/admin-rider.controller';
import { AdminDeliveryZoneController } from './controllers/admin/admin-delivery-zone.controller';
import { AdminPlatformSettingController } from './controllers/admin/admin-platform-setting.controller';
import { AdminPlaceBoundaryController } from './controllers/admin/admin-place-boundary.controller';
import { AdminDashboardController } from './controllers/admin/admin-dashboard.controller';

const ENTITIES = [
  RiderCoinTransaction,
  Delivery,
  DeliveryOffer,
  DeliveryZone,
  DeliveryZoneRevision,
  DispatchSetting,
  Rider,
];

const SERVICES = [
  RiderCoinsService,
  DispatchSettingsService,
  RoadDistanceService,
  ZoneBoundaryService,
  DeliveryZoneManager,
  PricingService,
  RiderCommissionService,
  RiderEarningsService,
  PlaceBoundarySearchService,
  RiderMatchingService,
  OfferExpiryScheduler,
  DeliveryService,
  RiderService,
  RemoteReferencesService,
  DispatchResourcesService,
  ServiceClientFactory,
  OrderEventsConsumer,
  OfferExpiryConsumer,
];

const CONTROLLERS = [
  InternalDeliveryZonesController,
  HealthController,
  RiderController,
  RiderOfferController,
  RiderDeliveryController,
  DispatchInternalController,
  // Register before AdminDeliveryZoneController so the static `preview`
  // segment resolves before the `:deliveryZone` parameterized route.
  AdminDeliveryZonePricingPreviewController,
  AdminDeliveryController,
  AdminRiderController,
  AdminDeliveryZoneController,
  AdminPlatformSettingController,
  AdminPlaceBoundaryController,
  AdminDashboardController,
];

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(DispatchEnvironmentVariables),
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
        database: config.get<string>('POSTGRES_DB_NAME') ?? DISPATCH_DB_NAME,
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
    EventsModule.forRoot(),
  ],
  controllers: CONTROLLERS,
  providers: SERVICES,
})
export class AppModule {}
