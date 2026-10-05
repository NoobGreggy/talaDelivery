import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  createEnvValidator,
  HealthController,
} from '@taladelivery/common';
import { AuthModule } from '@taladelivery/auth';
import { EventsModule } from '@taladelivery/events';
import { PAYMENT_DB_NAME, PaymentEnvironmentVariables } from './config/env';
import { Payment } from './entities/payment.entity';
import { PaymentAttempt } from './entities/payment-attempt.entity';
import { PaymentWebhookEvent } from './entities/payment-webhook-event.entity';
import { Refund } from './entities/refund.entity';

import { PaymentService } from './services/payment.service';
import { PaymentResourcesService } from './services/payment-resources.service';
import { OrderEventsConsumer } from './consumers/order-events.consumer';
import { DeliveryEventsConsumer } from './consumers/delivery-events.consumer';

import { PaymentsController } from './controllers/payments.controller';
import { AdminPaymentsController } from './controllers/admin/admin-payments.controller';
import { PaymentInternalController } from './controllers/internal/internal.controller';

const ENTITIES = [Payment, PaymentAttempt, PaymentWebhookEvent, Refund];

const PROVIDERS = [
  PaymentService,
  PaymentResourcesService,
  OrderEventsConsumer,
  DeliveryEventsConsumer,
];

const CONTROLLERS = [
  HealthController,
  PaymentsController,
  AdminPaymentsController,
  PaymentInternalController,
];

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(PaymentEnvironmentVariables),
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
        database: config.get<string>('POSTGRES_DB_NAME') ?? PAYMENT_DB_NAME,
        ssl:
          config.get<string>('POSTGRES_SSL') === 'true'
            ? { rejectUnauthorized: false }
            : false,
        autoLoadEntities: true,
        // Dev convenience; production uses structured migrations.
        synchronize: config.get<string>('NODE_ENV') !== 'production',
        logging: false,
      }),
    }),
    TypeOrmModule.forFeature(ENTITIES),
    AuthModule,
    EventsModule.forRoot(),
  ],
  controllers: CONTROLLERS,
  providers: PROVIDERS,
})
export class AppModule {}