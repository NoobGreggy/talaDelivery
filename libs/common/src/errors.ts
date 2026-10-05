import { ErrorCode } from '@taladelivery/contracts';

export interface AppErrorOptions {
  code?: string;
  errors?: Record<string, unknown> | null;
  cause?: unknown;
}

/**
 * Base class for expected business failures (nestjs_api.md §20.20).
 * Transport layers translate these into HTTP / WS / queue responses.
 */
export class AppError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly errors: Record<string, unknown> | null;

  constructor(statusCode: number, code: string, message: string, options?: AppErrorOptions) {
    super(message);
    this.name = new.target.name;
    this.statusCode = statusCode;
    this.code = code;
    this.errors = options?.errors ?? null;
    if (options?.cause !== undefined) {
      this.cause = options.cause;
    }
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found.', options?: AppErrorOptions) {
    super(404, options?.code ?? ErrorCode.NotFound, message, options);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'You are not allowed to perform this action.', options?: AppErrorOptions) {
    super(403, options?.code ?? ErrorCode.Forbidden, message, options);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthenticated.', options?: AppErrorOptions) {
    super(401, options?.code ?? ErrorCode.Unauthorized, message, options);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, errors: Record<string, unknown>, options?: AppErrorOptions) {
    super(422, options?.code ?? ErrorCode.ValidationFailed, message, { ...options, errors });
  }
}

/**
 * Business rule violation that Laravel surfaces as a 422 `ApiResponse::error`
 * (e.g. rider matching failures). Kept distinct from request-shape validation.
 */
export class DomainError extends AppError {
  constructor(message: string, options?: AppErrorOptions) {
    super(422, options?.code ?? ErrorCode.ValidationFailed, message, options);
  }
}

export class ConflictError extends AppError {
  constructor(message: string, options?: AppErrorOptions) {
    super(409, options?.code ?? ErrorCode.Conflict, message, options);
  }
}

export class RateLimitError extends AppError {
  constructor(message = 'Too many requests. Please slow down.', options?: AppErrorOptions) {
    super(429, options?.code ?? ErrorCode.RateLimited, message, options);
  }
}

export class InternalError extends AppError {
  constructor(message = 'Something went wrong.', options?: AppErrorOptions) {
    super(500, options?.code ?? ErrorCode.InternalError, message, options);
  }
}

/** Guards used to translate guard failures to 401/403 without leaking details. */
export function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}