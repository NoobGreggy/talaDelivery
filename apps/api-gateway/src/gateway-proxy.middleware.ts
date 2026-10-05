import { randomUUID } from 'node:crypto';
import { request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';
import type { NextFunction, Request, Response } from 'express';
import { resolveTarget } from './gateway.routes';

/**
 * Path prefixes the gateway serves itself (registered Nest controllers ->
 * health, and Swagger UI when enabled). Everything else is proxied.
 */
const GATEWAY_OWNED_PREFIXES = ['/health', '/docs', '/swagger'];

/**
 * `/` is owned by the gateway, but only as the exact path.
 *
 * It must NOT go into GATEWAY_OWNED_PREFIXES: the membership test below uses
 * `startsWith`, and every absolute path starts with `/`, which would make the
 * gateway answer 404 for the entire API instead of proxying it.
 */
function isGatewayOwned(pathname: string): boolean {
  if (pathname === '/') return true;
  return GATEWAY_OWNED_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  );
}

/**
 * Raw express proxy middleware (internal-contracts.md §5).
 *
 * Attached BEFORE the Nest router (but after the shared request-context /
 * helmet / CORS middleware) so it runs first for everything except the
 * gateway's own routes, which fall through to Nest via `next()`. It streams
 * the request to the owning service and streams the response back unchanged —
 * the service's own `{ success, message, data }` envelope passes through
 * verbatim (the gateway never double-wraps).
 *
 * Nest's express adapter registers the JSON body parser AFTER user `app.use()`
 * middleware, so at this point the raw body stream is still intact and is
 * piped as-is; a parsed `req.body` branch is kept as a defensive fallback.
 */
export function gatewayProxyMiddleware(req: Request, res: Response, next: NextFunction): void {
  const pathname = req.path ?? req.originalUrl.split('?')[0] ?? '/';

  if (isGatewayOwned(pathname)) {
    next();
    return;
  }

  const target = resolveTarget(pathname);

  if (target === null) {
    res.status(404).json({
      success: false,
      message: 'Not Found',
      errors: { path: ['No service is mapped to this route.'] },
    });
    return;
  }

  let upstream: URL;
  try {
    upstream = new URL(target.baseUrl);
  } catch {
    res.status(502).json({
      success: false,
      message: 'Bad Gateway',
      errors: { gateway: ['Upstream service URL is invalid.'] },
    });
    return;
  }

  // Forward JSON bodies from the parsed body when the body parser already ran
  // (defensive); otherwise the raw stream is piped below.
  const body = (req as Request & { body?: unknown }).body;
  let payload: Buffer | undefined;
  if (body !== undefined && body !== null && typeof body === 'object') {
    payload = Buffer.from(JSON.stringify(body), 'utf8');
  }

  const headers: Record<string, string | string[] | number | undefined> = {
    ...req.headers,
    // Contract §5: inject the app key, propagate correlation + user headers.
    'x-app-key': process.env.APP_API_KEY ?? '',
    'x-request-id': (req.headers['x-request-id'] as string | undefined) ?? randomUUID(),
    'x-correlation-id': (req.headers['x-correlation-id'] as string | undefined) ?? randomUUID(),
    host: upstream.host,
  };
  // Node manages connection pooling for the upstream socket itself.
  delete headers.connection;
  if (payload !== undefined) {
    headers['content-length'] = String(payload.length);
  }

  const transport = upstream.protocol === 'https:' ? httpsRequest : httpRequest;

  const upstreamRequest = transport(
    {
      protocol: upstream.protocol,
      hostname: upstream.hostname,
      port: upstream.port,
      method: req.method,
      path: req.originalUrl,
      headers,
    },
    (upstreamResponse) => {
      const status = upstreamResponse.statusCode ?? 502;
      // The public gateway owns browser origin policy, not the private services.
      const responseHeaders = Object.fromEntries(
        Object.entries(upstreamResponse.headers).filter(
          ([name]) => !name.toLowerCase().startsWith('access-control-'),
        ),
      );
      if (upstreamResponse.statusMessage) {
        res.writeHead(status, upstreamResponse.statusMessage, responseHeaders);
      } else {
        res.writeHead(status, responseHeaders);
      }
      upstreamResponse.pipe(res);
    },
  );

  upstreamRequest.on('error', (error: Error) => {
    if (res.headersSent) {
      res.destroy();
      return;
    }
    res.status(502).json({
      success: false,
      message: 'Bad Gateway',
      errors: { gateway: ['Upstream service unavailable.'] },
    });
    // eslint-disable-next-line no-console
    console.error(`[gateway] proxy error for ${req.method} ${req.originalUrl}: ${error.message}`);
  });

  if (payload !== undefined) {
    upstreamRequest.end(payload);
  } else {
    req.pipe(upstreamRequest);
  }
}
