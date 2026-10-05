import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import {
  Message,
  PaginatedResult,
  resolvePagination,
  requestContext,
} from '@taladelivery/common';
import { RiderLocationDto } from '../dto/rider-location.dto';
import { DispatchResourcesService } from '../services/dispatch-resources.service';
import { RiderService } from '../services/rider.service';
import { RiderEarningsService } from '../services/rider-earnings.service';

/**
 * Rider profile / availability / location / dashboards.
 * Mirrors Laravel RiderController (auth:sanctum, no role restriction).
 */
@Controller('rider')
@UseGuards(AppKeyGuard, JwtAuthGuard)
export class RiderController {
  constructor(
    private readonly riders: RiderService,
    private readonly resources: DispatchResourcesService,
    private readonly earnings: RiderEarningsService,
  ) {}

  @Get('profile')
  @Message('Rider profile retrieved.')
  async profile(@CurrentUser() user: JwtPayload) {
    const rider = await this.riders.profileByUserId(user.sub);
    if (rider === null) {
      throw new NotFoundException('Rider profile not found.');
    }
    const stats = await this.riders.stats(rider.id);
    const currentDelivery = await this.riders.currentDelivery(rider);
    return this.resources.riderToJson(rider, { currentDelivery, stats });
  }

  @Post('online')
  @Message('You are now online.')
  async online(@CurrentUser() user: JwtPayload) {
    const rider = await this.requireRider(user);
    const updated = await this.riders.goOnline(rider);
    const stats = await this.riders.stats(updated.id);
    const currentDelivery = await this.riders.currentDelivery(updated);
    return this.resources.riderToJson(updated, { currentDelivery, stats });
  }

  @Post('offline')
  @Message('You are now offline.')
  async offline(@CurrentUser() user: JwtPayload) {
    const rider = await this.requireRider(user);
    const updated = await this.riders.goOffline(rider);
    const stats = await this.riders.stats(updated.id);
    const currentDelivery = await this.riders.currentDelivery(updated);
    return this.resources.riderToJson(updated, { currentDelivery, stats });
  }

  @Post('location')
  @Message('Location updated.')
  async location(@CurrentUser() user: JwtPayload, @Body() dto: RiderLocationDto) {
    const rider = await this.requireRider(user);
    const updated = await this.riders.updateLocation(rider, dto);
    const stats = await this.riders.stats(updated.id);
    const currentDelivery = await this.riders.currentDelivery(updated);
    return this.resources.riderToJson(updated, { currentDelivery, stats });
  }

  @Get('deliveries')
  @Message('Deliveries retrieved.')
  async deliveries(
    @CurrentUser() user: JwtPayload,
    @Query('status') status?: string,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const rider = await this.requireRider(user);
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const { items, total } = await this.riders.deliveriesOf(rider.id, status, p, pp);

    const itemsJson = await Promise.all(
      items.map((delivery) =>
        this.resources.deliveryToJson(delivery, {
          rider,
        }),
      ),
    );

    return new PaginatedResult(
      itemsJson,
      {
        currentPage: p,
        lastPage: Math.max(1, Math.ceil(total / pp)),
        perPage: pp,
        total,
        path: requestContext().path,
      },
    );
  }

  @Get('earnings-summary')
  @Message('Rider earnings summary retrieved.')
  async earningsSummary(@CurrentUser() user: JwtPayload) {
    const rider = await this.requireRider(user);
    return this.earnings.summary(rider.id);
  }

  private async requireRider(user: JwtPayload) {
    const rider = await this.riders.profileByUserId(user.sub);
    if (rider === null) {
      throw new NotFoundException('Rider profile not found.');
    }
    return rider;
  }
}
