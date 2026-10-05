import { Module } from '@nestjs/common';
import { ServiceClientFactory } from '@taladelivery/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from '@taladelivery/auth';
import { createEnvValidator, HealthController } from '@taladelivery/common';
import { EventsModule } from '@taladelivery/events';
import { RealtimeEnvironmentVariables } from './config/env';
import { RealtimeGateway } from './realtime.gateway';
import { LocationEventsConsumer } from './consumers/location-events.consumer';
import { RealtimeFeedConsumer } from './consumers/realtime-feed.consumer';
import { RealtimeInternalController } from './controllers/internal.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(RealtimeEnvironmentVariables),
      envFilePath: ['.env.local', '.env'],
    }),
    AuthModule,
    // Sole consumer of `location-events`; the gateway is not enough on its own
    // because dispatch publishes positions as queue events, not over sockets.
    EventsModule.forRoot(),
  ],
  controllers: [HealthController, RealtimeInternalController],
  providers: [RealtimeGateway, LocationEventsConsumer, RealtimeFeedConsumer, ServiceClientFactory],
})
export class AppModule {}
