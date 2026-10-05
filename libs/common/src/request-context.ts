import { AsyncLocalStorage } from 'node:async_hooks';
import { Injectable, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';

/**
 * Per-request context stored in AsyncLocalStorage.
 * Mirrors Laravel request-scoped state (StoreContext + request id).
 */
export interface RequestContextData {
  requestId: string;
  correlationId: string;
  userId: number | null;
  role: string | null;
  userStatus: string | null;
  /** Resolved tenant for store routes (X-Store-Id). */
  storeId: number | null;
  ip: string | null;
  path: string;
  method: string;
}

const store = new AsyncLocalStorage<RequestContextData>();

export const getRequestContext = (): RequestContextData | undefined => store.getStore();

export function runWithRequestContext<T>(data: RequestContextData, fn: () => T): T {
  return store.run(data, fn);
}

export function requestContext(): RequestContextData {
  return (
    store.getStore() ?? {
      requestId: randomUUID(),
      correlationId: randomUUID(),
      userId: null,
      role: null,
      userStatus: null,
      storeId: null,
      ip: null,
      path: '',
      method: '',
    }
  );
}

export const REQUEST_CONTEXT_HEADERS = {
  requestId: 'x-request-id',
  correlationId: 'x-correlation-id',
  userId: 'x-user-id',
  role: 'x-user-role',
  userStatus: 'x-user-status',
  storeId: 'x-store-id',
  serviceToken: 'x-service-token',
} as const;

@Injectable()
export class RequestContextMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    const requestId = (req.get(REQUEST_CONTEXT_HEADERS.requestId) as string | undefined) ?? randomUUID();
    const correlationId =
      (req.get(REQUEST_CONTEXT_HEADERS.correlationId) as string | undefined) ?? requestId;

    res.setHeader(REQUEST_CONTEXT_HEADERS.requestId, requestId);
    if (!req.get(REQUEST_CONTEXT_HEADERS.correlationId)) {
      res.setHeader(REQUEST_CONTEXT_HEADERS.correlationId, correlationId);
    }

    const ctx: RequestContextData = {
      requestId,
      correlationId,
      userId: readIntHeader(req.get(REQUEST_CONTEXT_HEADERS.userId)),
      role: (req.get(REQUEST_CONTEXT_HEADERS.role) as string | undefined) ?? null,
      userStatus: (req.get(REQUEST_CONTEXT_HEADERS.userStatus) as string | undefined) ?? null,
      storeId: readIntHeader(req.get(REQUEST_CONTEXT_HEADERS.storeId)),
      ip: req.ip ?? null,
      path: req.originalUrl ?? req.url,
      method: req.method,
    };

    runWithRequestContext(ctx, () => next());
  }
}

function readIntHeader(value: string | undefined): number | null {
  if (value === undefined || value === '') return null;
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? null : parsed;
}