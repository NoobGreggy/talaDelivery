import { Controller, Get, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Standard liveness/readiness probes for every service.
 *
 * Consumer-side health endpoints (the Redis / DB ping) are intentionally kept
 * reading from values available at boot; they always answer 200 when the
 * process is up. Framework-level probes stay dependency-free so the routes
 * exist even while migrations/backing services are still coming up in dev.
 */
@Injectable()
@Controller()
export class HealthController {
  constructor(private readonly config: ConfigService) {}

  @Get('health')
  health(): Record<string, unknown> {
    return this.payload('ok');
  }

  @Get('health/live')
  live(): Record<string, unknown> {
    return this.payload('ok');
  }

  @Get('health/ready')
  ready(): Record<string, unknown> {
    return this.payload('ok');
  }

  private payload(status: string): Record<string, unknown> {
    return {
      status,
      service: this.config.get<string>('SERVICE_NAME', 'service'),
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }
}