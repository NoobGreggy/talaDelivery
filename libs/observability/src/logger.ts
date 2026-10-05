import { Injectable, LoggerService } from '@nestjs/common';
import pino, { type Logger as PinoLogger, type LoggerOptions } from 'pino';
import { randomUUID } from 'node:crypto';

export interface AppLoggerOptions {
  level?: string;
  serviceName?: string;
  environment?: string;
  /* Avoid timestamp fields for tests */
  pretty?: boolean;
}

/**
 * Structured JSON logger implementing NestJS LoggerService.
 * Fields: timestamp, level, service, environment, and contextual fields
 * appended by callers (requestId, correlationId, userId, orderId, ...).
 */
@Injectable()
export class AppLogger implements LoggerService {
  private readonly logger: PinoLogger;

  constructor(options: AppLoggerOptions = {}) {
    const pinoOptions: LoggerOptions = {
      level: options.level ?? process.env.LOG_LEVEL ?? 'info',
      base: {
        service: options.serviceName ?? process.env.SERVICE_NAME ?? 'taladelivery-backend',
        environment: options.environment ?? process.env.NODE_ENV ?? 'development',
      },
      timestamp: pino.stdTimeFunctions.isoTime,
      formatters: {
        level: (label) => ({ level: label }),
      },
      ...(options.pretty
        ? {
            transport: {
              target: 'pino-pretty',
              options: { colorize: true, singleLine: true },
            },
          }
        : {}),
    };
    this.logger = pino(pinoOptions);
  }

  private static contextFrom(context?: string): string {
    return context ?? 'Application';
  }

  log(message: unknown, context?: string): void {
    this.logger.info({ context: AppLogger.contextFrom(context) }, formatMessage(message));
  }

  error(message: unknown, stackOrContext?: string, context?: string): void {
    const stackProvided = typeof stackOrContext === 'string' && stackOrContext.includes('\n');
    this.logger.error(
      {
        context: context ?? (stackProvided ? undefined : stackOrContext) ?? 'Application',
        ...(stackProvided ? { stack: stackOrContext } : {}),
      },
      formatMessage(message),
    );
  }

  warn(message: unknown, context?: string): void {
    this.logger.warn({ context: AppLogger.contextFrom(context) }, formatMessage(message));
  }

  debug(message: unknown, context?: string): void {
    this.logger.debug({ context: AppLogger.contextFrom(context) }, formatMessage(message));
  }

  verbose(message: unknown, context?: string): void {
    this.logger.trace({ context: AppLogger.contextFrom(context) }, formatMessage(message));
  }

  fatal(message: unknown, context?: string): void {
    this.logger.fatal({ context: AppLogger.contextFrom(context) }, formatMessage(message));
  }

  child(bindings: Record<string, unknown>): pino.Logger {
    return this.logger.child(bindings);
  }

  /** Direct pino access for structured ad-hoc logging. */
  get pino(): PinoLogger {
    return this.logger;
  }

  /** Convenience: log with rich structured fields. */
  info(fields: Record<string, unknown>, message?: string): void {
    this.logger.info(fields, message ?? '');
  }
}

function formatMessage(message: unknown): string {
  if (typeof message === 'string') return message;
  try {
    return typeof message === 'object' ? JSON.stringify(message) : String(message);
  } catch {
    return String(message);
  }
}

export { randomUUID };
export type { PinoLogger };