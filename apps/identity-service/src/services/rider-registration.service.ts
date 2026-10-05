import { Injectable, Logger } from '@nestjs/common';
import { ServiceClientFactory } from '@taladelivery/common';
import type { ServiceCallError, ServiceClient } from '@taladelivery/common';
import { EventType, EventPublisher, QueueName } from '@taladelivery/events';
import { Role, type RiderProfileSnapshot } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { RefreshToken } from '../entities/refresh-token.entity';
import { hashToken } from './user.service';
import { UserService } from './user.service';
import { TokenGateway } from './token-gateway';
import { UserResourcesService, type UserResourceJson } from './user-resources.service';

export interface RiderRegistrationResult {
  token: string;
  refresh_token: string;
  user: UserResourceJson;
}

/**
 * POST /api/v1/rider/register (contracts §4):
 *  1. create the rider user (ACTIVE) in the identity DB
 *  2. call dispatch-service POST /internal/riders (PENDING profile)
 *  3. issue the token pair and respond 201
 * If dispatch cannot create the profile, the freshly created user is rolled
 * back so the system never keeps a rider without a dispatch profile.
 */
@Injectable()
export class RiderRegistrationService {
  private readonly logger = new Logger(RiderRegistrationService.name);
  private readonly dispatch: ServiceClient;

  constructor(
    private readonly users: UserService,
    private readonly resources: UserResourcesService,
    private readonly tokens: TokenGateway,
    factory: ServiceClientFactory,
    @InjectRepository(RefreshToken) private readonly refreshTokens: Repository<RefreshToken>,
    private readonly events: EventPublisher,
  ) {
    this.dispatch = factory.create('DISPATCH_SERVICE_URL');
  }

  async register(dto: {
    name: string;
    email: string;
    phone?: string | null;
    password: string;
    vehicle_type: string;
    vehicle_plate?: string | null;
    license_number?: string | null;
    requirements?: Record<string, unknown> | null;
  }): Promise<RiderRegistrationResult> {
    const user = await this.users.create({
      name: dto.name,
      email: dto.email,
      phone: dto.phone ?? null,
      password: dto.password,
      role: 'rider',
      status: 'ACTIVE',
    });

    let profile: RiderProfileSnapshot;
    try {
      profile = await this.dispatch.post<RiderProfileSnapshot>('/internal/riders', {
        userId: user.id,
        vehicleType: dto.vehicle_type,
        vehiclePlate: dto.vehicle_plate ?? null,
        licenseNumber: dto.license_number ?? null,
        requirements: dto.requirements ?? null,
      });
    } catch (error) {
      // Roll back the user so identity and dispatch never diverge.
      await this.users.delete(user.id);
      throw error as ServiceCallError;
    }

    const pair = await this.tokens.issuePair({
      id: user.id,
      email: user.email,
      role: 'rider',
      status: 'ACTIVE',
    });
    await this.refreshTokens.save(
      this.refreshTokens.create({
        userId: user.id,
        jti: pair.refreshTokenId,
        tokenHash: hashToken(pair.refreshToken),
        expiresAt: new Date(Date.now() + this.tokens.getRefreshTtlSeconds() * 1000),
        revokedAt: null,
      }),
    );

    await this.alertPlatformAdmins(user, profile);

    return {
      token: pair.accessToken,
      refresh_token: pair.refreshToken,
      user: this.resources.toUserJson(user, { rider: profile }),
    };
  }

  /**
   * A pending rider application is an admin work item. identity owns the users
   * table, so it resolves the platform admins itself and notifies them rather
   * than publishing a role-scoped event nobody would own.
   */
  private async alertPlatformAdmins(
    user: { id: number; name: string; email: string },
    profile: RiderProfileSnapshot,
  ): Promise<void> {
    const admins = await this.users.findActiveByRole(Role.PlatformAdmin);
    if (admins.length === 0) {
      this.logger.warn('Rider application received but no platform admin exists to notify');
      return;
    }
    const data = {
      userId: user.id,
      riderId: profile.id,
      name: user.name,
      email: user.email,
      vehicleType: profile.vehicleType,
    };
    for (const admin of admins) {
      await this.events.publishEvent(
        QueueName.NotificationJobs,
        EventType.NotificationCreate,
        {
          userId: admin.id,
          type: 'admin.rider_application',
          title: 'New rider application',
          body: `${user.name} (${user.email}) applied to ride with a ${String(profile.vehicleType).toLowerCase()}.`,
          data,
        },
      );
    }
    // Realtime nudge so an admin dashboard can react without polling.
    await this.events.publishEvent(
      QueueName.RealtimeFeed,
      EventType.RealtimeEmit,
      {
        rooms: ['admin:platform'],
        event: 'rider.application',
        data: { ...data, appliedAt: new Date().toISOString() },
      },
    );
    this.logger.log(`Rider application from user ${user.id} sent to ${admins.length} admin(s)`);
  }
}