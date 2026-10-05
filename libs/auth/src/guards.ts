import {
  CanActivate,
  ExecutionContext,
  Injectable,
  SetMetadata,
  createParamDecorator,
  UnauthorizedException,
  ForbiddenException,
  type CustomDecorator,
} from '@nestjs/common';
import type { Request } from 'express';
import { ConfigService } from '@nestjs/config';
import type { Role } from '@taladelivery/contracts';
import { requestContext } from '@taladelivery/common/request-context';
import type { JwtPayload } from './jwt-payload';
import { TokenService } from './token.service';

export const IS_PUBLIC_KEY = 'taladelivery:isPublic';
export const ROLES_KEY = 'taladelivery:roles';
export const OPTIONAL_AUTH_KEY = 'taladelivery:optionalAuth';

/** Marks a route as public (no JWT required). */
export const Public = (): CustomDecorator => SetMetadata(IS_PUBLIC_KEY, true);

/** Allows access with or without a token; user is attached when present. */
export const OptionalAuth = (): CustomDecorator => SetMetadata(OPTIONAL_AUTH_KEY, true);

/** Requires one of the given roles (mirrors Laravel spatie role middleware). */
export const Roles = (...roles: Role[]): CustomDecorator => SetMetadata(ROLES_KEY, roles);

export interface AuthedRequest extends Request {
  user?: JwtPayload;
}

/** Returns the authenticated JWT payload attached to the request. */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtPayload => {
    const request = ctx.switchToHttp().getRequest<AuthedRequest>();
    return request.user as JwtPayload;
  },
);

/** Guards the whole application with the shared X-App-Key header (Laravel EnsureAppKey). */
@Injectable()
export class AppKeyGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const expected = this.config.get<string>('APP_API_KEY');
    const provided = request.header('x-app-key');
    if (provided !== undefined && provided === expected) {
      return true;
    }
    throw new UnauthorizedException('Missing or invalid X-App-Key header.');
  }
}

/** Verifies the Bearer access token and attaches the payload to request.user. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly tokens: TokenService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const optional = Reflect.getMetadata(OPTIONAL_AUTH_KEY, context.getHandler()) ?? false;
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const authorization = request.header('authorization') ?? '';

    if (!authorization.startsWith('Bearer ')) {
      if (optional) {
        propagateForwardedUser(request);
        return true;
      }
      throw new UnauthorizedException('Unauthenticated.');
    }

    const token = authorization.slice('Bearer '.length).trim();
    const payload = await this.tokens.verifyAccess(token);
    request.user = payload;

    // Set request context fields so services can log user/role.
    const ctx = requestContext();
    if (ctx) {
      ctx.userId = payload.sub;
      ctx.role = payload.role;
      ctx.userStatus = payload.status;
    }

    return true;
  }
}

/**
 * During migrations the gateway forwards verified identity as headers.
 * When a request carries trusted x-user-* headers, adopt them as request.user.
 */
function propagateForwardedUser(request: AuthedRequest): void {
  const ctx = requestContext();
  if (ctx?.userId != null) {
    request.user = {
      sub: ctx.userId,
      email: request.header('x-user-email') ?? '',
      role: (ctx.role ?? 'customer') as Role,
      status: (ctx.userStatus ?? 'ACTIVE') as JwtPayload['status'],
      type: 'access',
      jti: '',
    };
  }
}

/** Role authorization guard (mirrors Laravel spatie role middleware behavior). */
@Injectable()
export class RolesGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = (Reflect.getMetadata(ROLES_KEY, context.getHandler()) ??
      Reflect.getMetadata(ROLES_KEY, context.getClass())) as Role[] | undefined;
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const user = request.user;
    if (!user) {
      throw new UnauthorizedException('Unauthenticated.');
    }
    if (!requiredRoles.includes(user.role)) {
      throw new ForbiddenException('You are not allowed to perform this action.');
    }
    return true;
  }
}

/** Service-to-service guard validating the shared X-Service-Token header. */
@Injectable()
export class ServiceAuthGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const expected = this.config.get<string>('INTERNAL_API_TOKEN');
    const provided = request.header('x-service-token');
    if (expected && provided === expected) {
      return true;
    }
    throw new UnauthorizedException('Unauthenticated.');
  }
}