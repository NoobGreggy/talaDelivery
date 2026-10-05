import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '@taladelivery/auth';
import { EventsModule } from '@taladelivery/events';
import { createEnvValidator, HealthController, ServiceClientFactory } from '@taladelivery/common';
import { ORDER_DB_NAME, OrderEnvironmentVariables } from './config/env';
import { Order } from './entities/order.entity';
import { OrderItem } from './entities/order-item.entity';
import { OrdersController } from './controllers/orders.controller';
import { AdminOrdersController } from './controllers/admin-orders.controller';
import { StoreOrdersController } from './controllers/store-orders.controller';
import { OrderInternalController } from './controllers/internal/internal.controller';
import { OrderService } from './services/order.service';
import { DeliveryEventsConsumer } from './consumers/delivery-events.consumer';
import { PaymentEventsConsumer } from './consumers/payment-events.consumer';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(OrderEnvironmentVariables),
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
        database: config.get<string>('POSTGRES_DB_NAME') ?? ORDER_DB_NAME,
        ssl: config.get<string>('POSTGRES_SSL') === 'true' ? { rejectUnauthorized: false } : false,
        autoLoadEntities: true,
        synchronize: config.get<string>('NODE_ENV') !== 'production',
        logging: false,
      }),
    }),
    TypeOrmModule.forFeature([Order, OrderItem]),
    AuthModule,
    EventsModule.forRoot(),
  ],
  controllers: [HealthController, OrdersController, AdminOrdersController, StoreOrdersController, OrderInternalController],
  providers: [OrderService, DeliveryEventsConsumer, PaymentEventsConsumer, ServiceClientFactory],
})
export class AppModule {}
