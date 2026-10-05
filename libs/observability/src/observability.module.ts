import { Global, Module, Logger } from '@nestjs/common';
import { AppLogger } from './logger';

@Global()
@Module({
  providers: [
    {
      provide: Logger,
      useFactory: (): AppLogger =>
        new AppLogger({
          level: process.env.LOG_LEVEL,
          serviceName: process.env.SERVICE_NAME,
          environment: process.env.NODE_ENV,
        }),
    },
  ],
  exports: [Logger],
})
export class ObservabilityModule {}

export { AppLogger, type AppLoggerOptions } from './logger';