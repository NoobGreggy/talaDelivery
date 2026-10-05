import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '@taladelivery/auth';
import { EventsModule } from '@taladelivery/events';
import { createEnvValidator, HealthController, ServiceClientFactory } from '@taladelivery/common';
import { NOTIFICATION_DB_NAME, NotificationEnvironmentVariables } from './config/env';
import { Notification } from './entities/notification.entity';
import { NotificationInternalController } from './controllers/internal/internal.controller';
import { NotificationsController } from './controllers/notifications.controller';
import { ScopedNotificationsController } from './controllers/scoped-notifications.controller';
import { NotificationService } from './services/notification.service';
import { NotificationConsumer } from './consumers/notification.consumer';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(NotificationEnvironmentVariables),
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
        database: config.get<string>('POSTGRES_DB_NAME') ?? NOTIFICATION_DB_NAME,
        ssl: config.get<string>('POSTGRES_SSL') === 'true' ? { rejectUnauthorized: false } : false,
        autoLoadEntities: true,
        synchronize: config.get<string>('NODE_ENV') !== 'production',
        logging: false,
      }),
    }),
    TypeOrmModule.forFeature([Notification]),
    AuthModule,
    EventsModule.forRoot(),
  ],
  controllers: [
    HealthController,
    NotificationInternalController,
    NotificationsController,
    ScopedNotificationsController,
  ],
  providers: [NotificationService, NotificationConsumer, ServiceClientFactory],
})
export class AppModule {}
