import { Injectable, Logger, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { requestContext } from '@taladelivery/common/request-context';

/**
 * Structured request logging: method, url, status, duration, requestId.
 */
@Injectable()
export class HttpLoggerMiddleware implements NestMiddleware {
  constructor(private readonly logger: Logger) {}

  use(req: Request, res: Response, next: NextFunction): void {
    const startedAt = process.hrtime.bigint();
    const ctx = requestContext();

    res.on('finish', () => {
      const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
      this.logger.log(
        {
          requestId: ctx?.requestId,
          correlationId: ctx?.correlationId,
          userId: ctx?.userId,
          role: ctx?.role,
          method: req.method,
          url: req.originalUrl ?? req.url,
          status: res.statusCode,
          durationMs: Math.round(durationMs * 100) / 100,
        },
        `${req.method} ${req.originalUrl ?? req.url} ${res.statusCode}`,
      );
    });

    next();
  }
}