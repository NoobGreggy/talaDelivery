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
  JwtAuthGuard,
  Roles,
  RolesGuard,
} from '@taladelivery/auth';
import { Message, PaginatedResult, resolvePagination, requestContext } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { Delivery } from '../../entities/delivery.entity';
import { DeliveryOffer } from '../../entities/delivery-offer.entity';
import { Rider } from '../../entities/rider.entity';
import { DeliveryService } from '../../services/delivery.service';
import { RiderService } from '../../services/rider.service';
import { DispatchResourcesService } from '../../services/dispatch-resources.service';
import { AssignDeliveryDto, CancelDeliveryAdminDto } from '../../dto/admin-delivery.dto';

/**
 * Admin delivery management (mirrors Laravel AdminDeliveryController).
 * Guards: X-App-Key + JWT + platform_admin.
 */
@Controller('admin/deliveries')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminDeliveryController {
  constructor(
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
    @InjectRepository(Rider) private readonly riders: Repository<Rider>,
    @InjectRepository(DeliveryOffer) private readonly offers: Repository<DeliveryOffer>,
    private readonly deliveryService: DeliveryService,
    private readonly riderService: RiderService,
    private readonly resources: DispatchResourcesService,
  ) {}

  @Get()
  @Message('Deliveries retrieved.')
  async index(
    @Query('status') status?: string,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const { items, total } = await this.riderService.adminDeliveries(status, p, pp);
    const ridersByDelivery = await this.ridersByDelivery(items);

    const itemsJson = await Promise.all(
      items.map((delivery) =>
        this.resources.deliveryToJson(delivery, {
          rider: ridersByDelivery.get(delivery.id) ?? null,
          skipHydration: true,
        }),
      ),
    );
    return new PaginatedResult(itemsJson, {
      currentPage: p,
      lastPage: Math.max(1, Math.ceil(total / pp)),
      perPage: pp,
      total,
      path: requestContext().path,
    });
  }

  @Get(':delivery')
  @Message('Delivery retrieved.')
  async show(@Param('delivery', ParseIntPipe) deliveryId: number) {
    const delivery = await this.findDelivery(deliveryId);
    const rider =
      delivery.riderId !== null
        ? await this.riders.findOne({ where: { id: delivery.riderId } })
        : null;
    const offers = await this.offers.find({
      where: { deliveryId },
      order: { id: 'ASC' },
    });
    return this.resources.deliveryToJson(delivery, { rider, offers });
  }

  @Post(':delivery/assign')
  @Message('Rider assigned to the delivery.')
  async assign(
    @Param('delivery', ParseIntPipe) deliveryId: number,
    @Body() dto: AssignDeliveryDto,
  ) {
    const delivery = await this.findDelivery(deliveryId);
    const rider = await this.riders.findOne({ where: { id: dto.rider_id } });
    if (rider === null) {
      throw new NotFoundException('This user is not an active rider.');
    }
    const updated = await this.deliveryService.assign(delivery, rider);
    await this.deliveryService.expirePendingOffers(deliveryId);
    return this.resources.deliveryToJson(updated, { rider });
  }

  @Post(':delivery/cancel')
  @Message('Delivery cancelled.')
  async cancel(
    @Param('delivery', ParseIntPipe) deliveryId: number,
    @Body() dto: CancelDeliveryAdminDto,
  ) {
    const delivery = await this.findDelivery(deliveryId);
    const updated = await this.deliveryService.cancel(delivery, 'admin', dto.reason ?? null);
    return this.resources.deliveryToJson(updated, {});
  }

  private async findDelivery(deliveryId: number): Promise<Delivery> {
    const delivery = await this.deliveries.findOne({ where: { id: deliveryId } });
    if (delivery === null) {
      throw new NotFoundException('Delivery not found.');
    }
    return delivery;
  }

  /** Load the assigned rider for each delivery, batched by delivery id. */
  private async ridersByDelivery(items: Delivery[]): Promise<Map<number, Rider>> {
    const riderIds = [
      ...new Set(
        items.map((d) => d.riderId).filter((id): id is number => id !== null),
      ),
    ];
    if (riderIds.length === 0) return new Map();
    const riders = await this.riders.find({ where: { id: In(riderIds) } });
    const byId = new Map(riders.map((r) => [r.id, r]));
    const map = new Map<number, Rider>();
    for (const delivery of items) {
      if (delivery.riderId !== null) {
        const rider = byId.get(delivery.riderId);
        if (rider !== undefined) map.set(delivery.id, rider);
      }
    }
    return map;
  }
}