import { Injectable } from '@nestjs/common';
import type { RiderProfileSnapshot } from '@taladelivery/contracts';
import { User } from '../entities/user.entity';
import { toIso } from '../common/format.util';

/**
 * Laravel UserResource-shaped API JSON for identity responses. `rider` and
 * `stores` live in other services, so they are only populated when a snapshot
 * is provided (never cross-DB joined).
 */
export interface UserResourceJson {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  role: string;
  status: string;
  roles: string[];
  permissions: string[];
  created_at: string | null;
  rider: RiderProfileSnapshot | null;
  stores: unknown[];
  orders_count: number;
  total_spent: number;
}

@Injectable()
export class UserResourcesService {
  toUserJson(
    user: User,
    opts: { rider?: RiderProfileSnapshot | null } = {},
  ): UserResourceJson {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone ?? null,
      role: user.role,
      status: user.status,
      roles: [user.role],
      permissions: [],
      created_at: toIso(user.createdAt),
      rider: opts.rider ?? null,
      stores: [],
      orders_count: 0,
      total_spent: 0,
    };
  }
}