import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  type JwtPayload,
  JwtAuthGuard,
  Roles,
  RolesGuard,
} from '@taladelivery/auth';
import { Message, PaginatedResult, requestContext, resolvePagination } from '@taladelivery/common';
import { EventType, EventPublisher, QueueName } from '@taladelivery/events';
import { Role, RiderStatus } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Rider } from '../../entities/rider.entity';
import { RiderService } from '../../services/rider.service';
import { DispatchResourcesService } from '../../services/dispatch-resources.service';
import { RemoteReferencesService } from '../../services/remote-references.service';
import { RiderCoinsService } from '../../services/rider-coins.service';
import { TopUpRiderCoinsDto } from '../../dto/rider-coins.dto';

/**
 * Admin rider approval workflow (mirrors Laravel AdminRiderController).
 * Notifications are delegated to notification-service via `notification.create`.
 */
@Controller('admin/riders')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminRiderController {
  constructor(
    @InjectRepository(Rider) private readonly riders: Repository<Rider>,
    private readonly riderService: RiderService,
    private readonly resources: DispatchResourcesService,
    private readonly refs: RemoteReferencesService,
    private readonly events: EventPublisher,
    private readonly coins: RiderCoinsService,
  ) {}

  @Get()
  @Message('Riders retrieved.')
  async index(
    @Query('status') status?: string,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const [items, total] = await this.riders.findAndCount({
      where: status ? { status } : {},
      order: { id: 'DESC' },
      skip: (p - 1) * pp,
      take: pp,
    });
    const users = await this.refs.usersByIds(items.map((r) => r.userId));
    const itemsJson = await Promise.all(
      items.map(async (rider) => {
        const stats = await this.riderService.stats(rider.id);
        const currentDelivery = await this.riderService.currentDelivery(rider);
        return this.resources.riderToJson(rider, {
          user: users.get(rider.userId) ?? null,
          currentDelivery,
          stats,
        });
      }),
    );
    return new PaginatedResult(itemsJson, {
      currentPage: p,
      lastPage: Math.max(1, Math.ceil(total / pp)),
      perPage: pp,
      total,
      path: requestContext().path,
    });
  }

  @Get(':rider')
  @Message('Rider retrieved.')
  async show(@Param('rider', ParseIntPipe) riderId: number) {
    const rider = await this.findRider(riderId);
    const stats = await this.riderService.stats(rider.id);
    const currentDelivery = await this.riderService.currentDelivery(rider);
    return this.resources.riderToJson(rider, { currentDelivery, stats });
  }

  @Post(':rider/approve')
  @Message('Rider approved.')
  async approve(@Param('rider', ParseIntPipe) riderId: number) {
    const rider = await this.findRider(riderId);
    const updated = await this.setStatus(rider, RiderStatus.Offline);
    await this.notify(
      rider.userId,
      'rider.approved',
      'Application approved',
      'Congratulations! Your rider application has been approved. You can now go online.',
      rider.id,
    );
    return this.resources.riderToJson(updated, {});
  }

  @Get(':rider/coins')
  @Message('Tala Coins history retrieved.')
  async coinHistory(@Param('rider', ParseIntPipe) riderId: number, @Query('page') page?: number, @Query('per_page') perPage?: number) {
    await this.findRider(riderId);
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const { items, total } = await this.coins.history(riderId, p, pp);
    return new PaginatedResult(items, {
      currentPage: p, lastPage: Math.max(1, Math.ceil(total / pp)), perPage: pp,
      total, path: requestContext().path,
    });
  }

  @Post(':rider/coins/top-up')
  @Message('Tala Coins added.')
  async topUp(@Param('rider', ParseIntPipe) riderId: number, @CurrentUser() user: JwtPayload, @Body() dto: TopUpRiderCoinsDto) {
    await this.findRider(riderId);
    await this.coins.topUp(riderId, dto, user.sub);
    return this.show(riderId);
  }

  @Post(':rider/reject')
  @Message('Rider rejected.')
  async reject(
    @Param('rider', ParseIntPipe) riderId: number,
    @Body('reason') reason?: string,
  ) {
    const rider = await this.findRider(riderId);
    const message = reason?.trim() ?? '';
    const updated = await this.setStatus(rider, RiderStatus.Rejected);
    await this.notify(
      rider.userId,
      'rider.rejected',
      'Application rejected',
      message !== '' ? message : 'Your rider application was not approved.',
      rider.id,
    );
    return this.resources.riderToJson(updated, {});
  }

  @Post(':rider/suspend')
  @Message('Rider suspended.')
  async suspend(
    @Param('rider', ParseIntPipe) riderId: number,
    @Body('reason') reason?: string,
  ) {
    const rider = await this.findRider(riderId);
    const message = reason?.trim() ?? '';
    const updated = await this.setStatus(rider, RiderStatus.Suspended);
    await this.notify(
      rider.userId,
      'rider.suspended',
      'Account suspended',
      message !== '' ? message : 'Your rider account has been suspended.',
      rider.id,
    );
    return this.resources.riderToJson(updated, {});
  }

  private async setStatus(rider: Rider, status: RiderStatus): Promise<Rider> {
    rider.status = status;
    await this.riders.update({ id: rider.id }, { status });
    return this.findRider(rider.id);
  }

  private async notify(
    userId: number,
    type: string,
    title: string,
    body: string,
    riderId: number,
  ): Promise<void> {
    await this.events.publishEvent(
      QueueName.NotificationJobs,
      EventType.NotificationCreate,
      { userId, type, title, body, data: { rider_id: riderId } },
      requestContext().correlationId,
    );
  }

  private async findRider(riderId: number): Promise<Rider> {
    const rider = await this.riders.findOne({ where: { id: riderId } });
    if (rider === null) {
      throw new NotFoundException('Rider not found.');
    }
    return rider;
  }
}
