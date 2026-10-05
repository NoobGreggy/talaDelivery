import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ExceptionFilter,
  ForbiddenException,
  HttpException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import type { Response } from 'express';
import type { ErrorEnvelope } from '@taladelivery/contracts';
import { AppError } from './errors';
import { requestContext } from './request-context';

/**
 * Maps errors to the Laravel-compatible envelope:
 *   { success: false, message, errors, code?, requestId? }
 * Never leaks stack traces, SQL errors, internal hostnames or secrets.
 */
@Catch()
export class AppExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const requestId = requestContext()?.requestId;

    const { statusCode, body } = this.map(exception, ctx.getRequest<{ url?: string; method?: string }>());

    response.status(statusCode).json({
      success: false,
      ...body,
      requestId,
    } satisfies ErrorEnvelope);
  }

  private map(
    exception: unknown,
    request: { url?: string; method?: string },
  ): { statusCode: number; body: Omit<ErrorEnvelope, 'success' | 'requestId'> } {
    if (exception instanceof AppError) {
      return {
        statusCode: exception.statusCode,
        body: { message: exception.message, errors: exception.errors, code: exception.code },
      };
    }

    if (exception instanceof ThrottlerException) {
      return { statusCode: 429, body: { message: 'Too many requests. Please slow down.', errors: null } };
    }

    if (exception instanceof UnauthorizedException) {
      return { statusCode: 401, body: { message: 'Unauthenticated.', errors: null } };
    }

    if (exception instanceof ForbiddenException) {
      return {
        statusCode: 403,
        body: { message: 'You are not allowed to perform this action.', errors: null },
      };
    }

    if (exception instanceof NotFoundException) {
      return { statusCode: 404, body: { message: 'Resource not found.', errors: null } };
    }

    if (exception instanceof BadRequestException) {
      const responseBody = exception.getResponse();
      const message =
        typeof responseBody === 'string'
          ? responseBody
          : ((responseBody as { message?: string | string[] }).message ?? 'The given data was invalid.');
      return {
        statusCode: 400,
        body: { message: Array.isArray(message) ? message.join(', ') : message, errors: null },
      };
    }

    if (exception instanceof HttpException) {
      const responseBody = exception.getResponse();
      const message =
        typeof responseBody === 'string'
          ? responseBody
          : ((responseBody as { message?: string | string[] }).message ?? 'Request failed.');
      return {
        statusCode: exception.getStatus(),
        body: { message: Array.isArray(message) ? message.join(', ') : message, errors: null },
      };
    }

    // Unknown error - log the real detail, return a safe envelope.
    const err = exception instanceof Error ? exception : new Error(String(exception));
    // eslint-disable-next-line no-console
    console.error({
      level: 'error',
      requestId: requestContext()?.requestId,
      method: request.method,
      url: request.url,
      error: err.message,
      stack: err.stack,
    });
    return {
      statusCode: 500,
      body: { message: 'Something went wrong.', errors: null, code: 'INTERNAL_ERROR' },
    };
  }
}