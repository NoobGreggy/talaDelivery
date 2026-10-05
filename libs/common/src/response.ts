import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import type { SuccessEnvelope } from '@taladelivery/contracts';
import { requestContext } from './request-context';

export const RESPONSE_MESSAGE_KEY = 'taladelivery:responseMessage';

/** Sets the `message` field of the success envelope for a handler. */
export function Message(message: string): MethodDecorator {
  return (
    target: object,
    propertyKey: string | symbol,
    descriptor: PropertyDescriptor,
  ) => {
    Reflect.defineMetadata(RESPONSE_MESSAGE_KEY, message, descriptor.value);
  };
}

/** Result wrapper that the interceptor serializes into a Laravel-style page. */
export class PaginatedResult<T> {
  constructor(
    public readonly data: T[],
    public readonly meta: {
      currentPage: number;
      lastPage: number;
      perPage: number;
      total: number;
      path: string;
      /**
       * Optional extra counters merged into the emitted `meta` object
       * (e.g. `unread`, `by_type`). Keys are emitted verbatim, so use
       * snake_case here.
       */
      extra?: Record<string, unknown>;
    },
  ) {}
}

export interface PaginationQuery {
  page?: number;
  perPage?: number;
}

export function resolvePagination(query: PaginationQuery, defaultPerPage = 15): { page: number; perPage: number } {
  const page = Math.max(1, Math.trunc(query.page ?? 1));
  const perPage = Math.max(1, Math.trunc(query.perPage ?? defaultPerPage));
  return { page, perPage };
}

export function paginatedResult<T>(
  items: T[],
  total: number,
  page: number,
  perPage: number,
  path: string,
): PaginatedResult<T> {
  const lastPage = Math.max(1, Math.ceil(total / perPage));
  return new PaginatedResult(items, { currentPage: page, lastPage, perPage, total, path });
}

const pageUrl = (path: string, page: number, perPage: number): string | null => {
  const sep = path.includes('?') ? '&' : '?';
  return `${path}${sep}page=${page}&per_page=${perPage}`;
};

/**
 * Wraps every controller response in the Laravel-compatible envelope:
 *   { success, message, data }  |  paginated -> { success, message, data: { data, links, meta } }
 */
@Injectable()
export class ResponseEnvelopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<SuccessEnvelope> {
    const handler = context.getHandler();
    const message =
      Reflect.getMetadata(RESPONSE_MESSAGE_KEY, handler) ??
      (Reflect.getMetadata(RESPONSE_MESSAGE_KEY, handler.constructor) as string | undefined) ??
      'OK';

    return next.handle().pipe(
      map((raw: unknown) => {
        if (raw instanceof PaginatedResult) {
          const { data, meta } = raw;
          const path = requestContext().path;
          return {
            success: true,
            message,
            data: {
              data,
              links: {
                first: pageUrl(path, 1, meta.perPage),
                last: pageUrl(path, meta.lastPage, meta.perPage),
                prev: meta.currentPage > 1 ? pageUrl(path, meta.currentPage - 1, meta.perPage) : null,
                next: meta.currentPage < meta.lastPage ? pageUrl(path, meta.currentPage + 1, meta.perPage) : null,
              },
              meta: {
                current_page: meta.currentPage,
                from: data.length > 0 ? (meta.currentPage - 1) * meta.perPage + 1 : null,
                last_page: meta.lastPage,
                path,
                per_page: meta.perPage,
                to: data.length > 0 ? (meta.currentPage - 1) * meta.perPage + data.length : null,
                total: meta.total,
                ...(meta.extra ?? {}),
              },
            },
          };
        }
        return {
          success: true,
          message,
          data: raw === undefined ? null : raw,
        };
      }),
    );
  }
}