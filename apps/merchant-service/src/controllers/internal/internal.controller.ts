import { Body, Controller, Get, Param, ParseIntPipe, Post, Query, UseGuards } from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { CreateStoreDto, StoreUserDto } from '../../dto/store.dto';
import { StoreService } from '../../services/store.service';

/** Internal contract documented in docs/internal-contracts.md §1.2. */
@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class MerchantInternalController {
  constructor(private readonly stores: StoreService) {}

  @Get('stores/:id')
  async byId(@Param('id', ParseIntPipe) id: number) { return this.stores.snapshot(await this.stores.require(id)); }

  @Get('stores/batch')
  async batch(@Query('ids') ids?: string) {
    const parsed = (ids ?? '').split(',').map(Number).filter((id) => Number.isInteger(id) && id > 0);
    const found = await Promise.all(parsed.map((id) => this.stores.byId(id)));
    return found.filter((store): store is NonNullable<typeof store> => store !== null).map((store) => this.stores.snapshot(store));
  }

  @Post('stores')
  async create(@Body() dto: CreateStoreDto) { return this.stores.snapshot(await this.stores.create(dto)); }

  @Post('store-users')
  async addUser(@Body() dto: StoreUserDto) { const row = await this.stores.addUser(dto.storeId, dto.userId); return { id: row.id, storeId: row.storeId, userId: row.userId }; }

  @Post('store-users/verify')
  async verifyUser(@Body() dto: StoreUserDto) { await this.stores.verifyUser(dto.storeId, dto.userId); return { storeId: dto.storeId, userId: dto.userId }; }

  @Get('stores/:id/store-users')
  async storeUsers(@Param('id', ParseIntPipe) id: number) { return { userIds: await this.stores.userIds(id) }; }

  @Get('stores/by-user/:userId')
  async byUser(@Param('userId', ParseIntPipe) userId: number) {
    return (await this.stores.storesForUser(userId)).map((store) => this.stores.snapshot(store));
  }

  @Get('admin/totals')
  async totals() { return { stores: await this.stores.count() }; }
}
