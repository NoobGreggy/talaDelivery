import { Body, Controller, Get, Param, ParseIntPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import { AppKeyGuard, JwtAuthGuard, Roles, RolesGuard } from '@taladelivery/auth';
import { Message, PaginatedResult, requestContext, resolvePagination } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { CreateStoreDto, UpdateStoreDto } from '../../dto/store.dto';
import { StoreService } from '../../services/store.service';
import { StoreCategoryService } from '../../services/store-category.service';
import { StoreCategoryTagsDto } from '../../dto/store-category.dto';
import { StoreDeliveryZonesDto } from '../../dto/store-delivery-zones.dto';
import { StoreDeliveryZonesService } from '../../services/store-delivery-zones.service';

/**
 * Admin store management (mirrors Laravel AdminStoreController).
 *
 * Guards: X-App-Key + JWT + platform_admin. Mounted at `admin/stores`, the
 * prefix the gateway already routes to merchant-service.
 *
 * The public `GET /stores` deliberately exposes ACTIVE stores only; this
 * listing spans every status so an admin can review and reinstate a
 * suspended store. Store data is owned exclusively by merchant-service, so
 * nothing here is hydrated from other services.
 */
@Controller('admin/stores')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminStoreController {
  constructor(private readonly stores: StoreService, private readonly categories: StoreCategoryService,
    private readonly deliveryZones: StoreDeliveryZonesService) {}

  @Put(':id/delivery-zones') @Message('Store delivery zones updated.')
  async assignDeliveryZones(@Param('id', ParseIntPipe) id: number, @Body() dto: StoreDeliveryZonesDto) {
    await this.deliveryZones.assign(id, dto.delivery_zone_ids);
    return this.stores.snapshot(await this.stores.require(id));
  }

  @Get()
  @Message('Stores retrieved.')
  async index(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const term = search === undefined ? undefined : search.replace(/\s+/g, ' ').trim();

    const { items, total } = await this.stores.paginate({
      page: p,
      perPage: pp,
      search: term === '' ? undefined : term,
      status,
    });

    return new PaginatedResult(items.map((store) => this.stores.snapshot(store)), {
      currentPage: p,
      lastPage: Math.max(1, Math.ceil(total / pp)),
      perPage: pp,
      total,
      path: requestContext().path,
    });
  }

  @Get(':id')
  @Message('Store retrieved.')
  async show(@Param('id', ParseIntPipe) id: number) {
    return this.stores.snapshot(await this.stores.require(id));
  }

  @Post()
  @Message('Store created.')
  async create(@Body() dto: CreateStoreDto) {
    return this.stores.snapshot(await this.stores.create(dto));
  }

  @Put(':id/categories')
  @Message('Store categories updated.')
  async tagStore(@Param('id', ParseIntPipe) id: number, @Body() dto: StoreCategoryTagsDto) {
    await this.categories.tagStore(id, dto.category_ids);
    return this.stores.snapshot(await this.stores.require(id));
  }

  @Put(':id')
  @Message('Store updated.')
  async update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateStoreDto) {
    return this.stores.snapshot(await this.stores.update(await this.stores.require(id), dto));
  }
}
