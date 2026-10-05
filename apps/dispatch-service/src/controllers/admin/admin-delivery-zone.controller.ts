import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  Roles,
  RolesGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import { Message, PaginatedResult, requestContext, resolvePagination } from '@taladelivery/common';
import { DeliveryZoneStatus, Role } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeliveryZone } from '../../entities/delivery-zone.entity';
import { DeliveryZoneRevision } from '../../entities/delivery-zone-revision.entity';
import { DeliveryZoneManager, type ZoneInput } from '../../services/delivery-zone-manager.service';
import { DispatchResourcesService } from '../../services/dispatch-resources.service';
import { RemoteReferencesService } from '../../services/remote-references.service';
import {
  StoreDeliveryZoneDto,
  UpdateDeliveryZoneDto,
} from '../../dto/delivery-zone.dto';
import { squish } from '../../services/pricing.service';

/**
 * Admin delivery-zone CRUD (mirrors Laravel AdminDeliveryZoneController).
 * Publish rules (city-wide fallback uniqueness, boundary overlap) live in
 * DeliveryZoneManager.
 */
@Controller('admin/delivery-zones')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminDeliveryZoneController {
  constructor(
    @InjectRepository(DeliveryZone) private readonly zones: Repository<DeliveryZone>,
    @InjectRepository(DeliveryZoneRevision)
    private readonly revisions: Repository<DeliveryZoneRevision>,
    private readonly manager: DeliveryZoneManager,
    private readonly resources: DispatchResourcesService,
    private readonly refs: RemoteReferencesService,
  ) {}

  @Get()
  @Message('Delivery zones retrieved.')
  async index(
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const query = this.zones
      .createQueryBuilder('zone')
      .orderBy('zone.created_at', 'DESC')
      .addOrderBy('zone.id', 'DESC')
      .skip((p - 1) * pp)
      .take(pp);

    if (status) {
      query.andWhere('zone.status = :status', { status });
    }
    if (search) {
      const term = `%${squish(search)}%`;
      query.andWhere(
        '(zone.name ILIKE :s OR zone.city ILIKE :s OR zone.province ILIKE :s)',
        { s: term },
      );
    }

    const [items, total] = await query.getManyAndCount();

    const itemsJson = await Promise.all(
      items.map(async (zone) => {
        const revisionCount = await this.revisions.count({
          where: { deliveryZoneId: zone.id },
        });
        return this.resources.zoneToJson(zone, {
          updatedBy: await this.updatedBy(zone),
          revisionCount,
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

  @Post()
  @Message('Delivery zone created.')
  async store(@CurrentUser() user: JwtPayload, @Body() dto: StoreDeliveryZoneDto) {
    const input = this.toZoneInput(dto, true);
    const zone = await this.manager.create(input, user.sub);
    const updatedBy = await this.refs.userById(user.sub);
    return this.resources.zoneToJson(zone, {
      updatedBy: updatedBy === null ? null : { id: updatedBy.id, name: updatedBy.name },
    });
  }

  @Get(':deliveryZone')
  @Message('Delivery zone retrieved.')
  async show(@Param('deliveryZone', ParseIntPipe) zoneId: number) {
    const zone = await this.findZone(zoneId);
    const revisionCount = await this.revisions.count({
      where: { deliveryZoneId: zone.id },
    });
    const revisionRows = await this.revisions.find({
      where: { deliveryZoneId: zone.id },
      order: { createdAt: 'DESC' },
      take: 20,
    });
    const users = await this.refs.usersByIds(
      revisionRows.map((r) => r.userId ?? 0).filter((id) => id > 0),
    );
    const updatedBy =
      zone.updatedBy === null
        ? null
        : ((await this.refs.userById(zone.updatedBy)) ?? null);
    return this.resources.zoneToJson(zone, {
      updatedBy: updatedBy === null ? null : { id: updatedBy.id, name: updatedBy.name },
      revisionCount,
      revisions: revisionRows,
      revisionUsers: users,
    });
  }

  @Put(':deliveryZone')
  @Message('Delivery zone updated.')
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('deliveryZone', ParseIntPipe) zoneId: number,
    @Body() dto: UpdateDeliveryZoneDto,
  ) {
    const zone = await this.findZone(zoneId);
    const updated = await this.manager.update(zone, this.toZoneInput(dto, false), user.sub);
    return this.resources.zoneToJson(updated, {});
  }

  @Delete(':deliveryZone')
  @Message('Delivery zone archived.')
  async destroy(
    @CurrentUser() user: JwtPayload,
    @Param('deliveryZone', ParseIntPipe) zoneId: number,
  ) {
    const zone = await this.findZone(zoneId);
    const archived = await this.manager.archive(zone, user.sub);
    return this.resources.zoneToJson(archived, {});
  }

  private toZoneInput(dto: StoreDeliveryZoneDto | UpdateDeliveryZoneDto, isStore: boolean): ZoneInput {
    const input: ZoneInput = {};
    if (dto.tala_coins_percent !== undefined) input.talaCoinsPercent = dto.tala_coins_percent;
    if ('name' in dto && dto.name !== undefined) input.name = dto.name;
    if (dto.city !== undefined) input.city = dto.city ?? null;
    if (dto.province !== undefined) input.province = dto.province;
    if (dto.boundary_geojson !== undefined) {
      input.boundaryGeoJson = dto.boundary_geojson as ZoneInput['boundaryGeoJson'];
    }
    if ('base_fee' in dto && dto.base_fee !== undefined) input.baseFee = dto.base_fee;
    if ('included_km' in dto && dto.included_km !== undefined) input.includedKm = dto.included_km;
    if ('maximum_delivery_km' in dto && dto.maximum_delivery_km !== undefined) {
      input.maximumDeliveryKm = dto.maximum_delivery_km ?? null;
    }
    if ('extra_fee_per_km' in dto && dto.extra_fee_per_km !== undefined) {
      input.extraFeePerKm = dto.extra_fee_per_km;
    }
    if ('maximum_delivery_fee' in dto && dto.maximum_delivery_fee !== undefined) {
      input.maximumDeliveryFee = dto.maximum_delivery_fee ?? null;
    }
    if ('distance_rounding_km' in dto && dto.distance_rounding_km !== undefined) {
      input.distanceRoundingKm = dto.distance_rounding_km;
    } else if (isStore) {
      input.distanceRoundingKm = '0.1';
    }
    if (dto.effective_from !== undefined && dto.effective_from !== null && dto.effective_from !== '') {
      input.effectiveFrom = new Date(dto.effective_from);
    } else if (dto.effective_from !== undefined) {
      input.effectiveFrom = null;
    }
    if (dto.status !== undefined) {
      // Laravel maps INACTIVE -> ARCHIVED on both store and update.
      input.status =
        dto.status === 'INACTIVE' ? DeliveryZoneStatus.Archived : dto.status;
    } else if (isStore) {
      input.status = DeliveryZoneStatus.Active;
    }
    return input;
  }

  private async findZone(zoneId: number): Promise<DeliveryZone> {
    const zone = await this.zones.findOne({ where: { id: zoneId } });
    if (zone === null) {
      throw new NotFoundException('Delivery zone not found.');
    }
    return zone;
  }

  private async updatedBy(
    zone: DeliveryZone,
  ): Promise<{ id: number; name: string } | null> {
    if (zone.updatedBy === null) {
      return null;
    }
    const user = await this.refs.userById(zone.updatedBy);
    return user === null ? null : { id: user.id, name: user.name };
  }
}
