/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
/**
 * Runtime stub for `@nestjs/common` (NestJS 12 ships pure ESM: `"type":
 * "module"`). Jest's CommonJS module runtime cannot parse ESM packages, so
 * unit tests that exercise service logic map `@nestjs/common` to this stub
 * through `moduleNameMapper` (see jest.config.js).
 *
 * Only the members reached at RUNTIME by the tested graph need to exist here;
 * type-only imports keep resolving against the real package during
 * typechecking, so the types below are mere placeholders.
 */
export interface INestApplication {}
export interface DynamicModule {}
export interface NestMiddleware<Request = any, Response = any> {}
export interface CallHandler<T = any> {}
export interface ExecutionContext {}
export interface ExceptionFilter<T = any> {}
export interface ArgumentsHost {}
export interface NestInterceptor<T = any, R = any> {}
export interface OnModuleInit {}
export interface OnApplicationShutdown {}
export interface ModuleMetadata {}
export interface Type<T = any> extends Function {}
export interface RequestMethod {}
export interface PipeTransform<T = any, R = any> {}

/** Class decorator used by every service; a no-op for manually-built tests. */
export function Injectable(): ClassDecorator {
  return () => undefined;
}

/** Parameter decorator used for DI tokens; a no-op under manual construction. */
export function Inject(token?: unknown): ParameterDecorator {
  return () => undefined;
}

export function Optional(): ParameterDecorator {
  return () => undefined;
}

export function Controller(prefix?: string | string[]): ClassDecorator {
  return () => undefined;
}

export function Global(): ClassDecorator {
  return () => undefined;
}

export function Module(metadata: ModuleMetadata): ClassDecorator {
  return () => undefined;
}

export function Catch(...exceptions: Array<unknown>): ClassDecorator {
  return () => undefined;
}

export function SetMetadata(key: string, value: unknown): MethodDecorator {
  return () => undefined;
}

export function UseGuards(...guards: Array<unknown>): MethodDecorator {
  return () => undefined;
}

export function UseInterceptors(...interceptors: Array<unknown>): MethodDecorator {
  return () => undefined;
}

export function UsePipes(...pipes: Array<unknown>): MethodDecorator {
  return () => undefined;
}

function httpMethodDecorator(): MethodDecorator {
  return () => undefined;
}

export function Get(path?: string | string[]): MethodDecorator {
  return () => undefined;
}
export function Post(path?: string | string[]): MethodDecorator {
  return () => undefined;
}
export function Put(path?: string | string[]): MethodDecorator {
  return () => undefined;
}
export function Patch(path?: string | string[]): MethodDecorator {
  return () => undefined;
}
export function Delete(path?: string | string[]): MethodDecorator {
  return () => undefined;
}
export function Head(path?: string | string[]): MethodDecorator {
  return () => undefined;
}
export function Options(path?: string | string[]): MethodDecorator {
  return () => undefined;
}
export function All(path?: string | string[]): MethodDecorator {
  return () => undefined;
}

export function Body(property?: string): ParameterDecorator {
  return () => undefined;
}
export function Query(property?: string): ParameterDecorator {
  return () => undefined;
}
export function Param(property?: string): ParameterDecorator {
  return () => undefined;
}
export function Headers(property?: string): ParameterDecorator {
  return () => undefined;
}
export function Req(): ParameterDecorator {
  return () => undefined;
}
export function Res(): ParameterDecorator {
  return () => undefined;
}
export function Ip(): ParameterDecorator {
  return () => undefined;
}

/** Simple no-op logger so `new Logger(...)`/`.log()` calls in services work. */
export class Logger {
  constructor(private readonly context?: string) {}

  log(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }

  error(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }

  warn(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }

  debug(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }

  verbose(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }

  static log(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }

  static error(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }

  static warn(message: unknown, ...optionalParams: unknown[]): void {
    // no-op
  }
}

/**
 * Stand-in validation pipe. `laravelValidationPipe()` constructs one but the
 * real transform is never exercised in unit tests.
 */
export class ValidationPipe {
  constructor(options?: Record<string, unknown>) {
    // no-op
  }

  transform(value: unknown, metadata?: unknown): unknown {
    return value;
  }
}

export class ParseIntPipe {
  constructor(options?: Record<string, unknown>) {
    // no-op
  }

  transform(value: unknown, metadata?: unknown): number {
    return Number(value);
  }
}

export class ParseUUIDPipe {
  constructor(options?: Record<string, unknown>) {
    // no-op
  }

  transform(value: unknown, metadata?: unknown): string {
    return String(value);
  }
}

/** Exception classes referenced by the shared exception filter. */
export class HttpException extends Error {
  readonly response: string | Record<string, unknown>;
  readonly status: number;

  constructor(response: string | Record<string, unknown>, status: number) {
    super(typeof response === 'string' ? response : 'Http Exception');
    this.name = 'HttpException';
    this.response = response;
    this.status = status;
  }

  getStatus(): number {
    return this.status;
  }

  getResponse(): string | Record<string, unknown> {
    return this.response;
  }
}

export class BadRequestException extends HttpException {
  constructor(response?: string | Record<string, unknown>) {
    super(response ?? 'Bad Request', 400);
    this.name = 'BadRequestException';
  }
}

export class UnauthorizedException extends HttpException {
  constructor(response?: string | Record<string, unknown>) {
    super(response ?? 'Unauthorized', 401);
    this.name = 'UnauthorizedException';
  }
}

export class ForbiddenException extends HttpException {
  constructor(response?: string | Record<string, unknown>) {
    super(response ?? 'Forbidden', 403);
    this.name = 'ForbiddenException';
  }
}

export class NotFoundException extends HttpException {
  constructor(response?: string | Record<string, unknown>) {
    super(response ?? 'Not Found', 404);
    this.name = 'NotFoundException';
  }
}

export class ConflictException extends HttpException {
  constructor(response?: string | Record<string, unknown>) {
    super(response ?? 'Conflict', 409);
    this.name = 'ConflictException';
  }
}

export class PayloadTooLargeException extends HttpException {
  constructor(response?: string | Record<string, unknown>) {
    super(response ?? 'Payload Too Large', 413);
    this.name = 'PayloadTooLargeException';
  }
}

export class InternalServerErrorException extends HttpException {
  constructor(response?: string | Record<string, unknown>) {
    super(response ?? 'Internal Server Error', 500);
    this.name = 'InternalServerErrorException';
  }
}