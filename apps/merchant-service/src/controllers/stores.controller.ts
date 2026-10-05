import { Body, Controller, Get, Param, ParseIntPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import { AppKeyGuard, CurrentUser, JwtAuthGuard, Roles, RolesGuard, type JwtPayload } from '@taladelivery/auth';
import { Message } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { CreateStoreDto, UpdateStoreDto } from '../dto/store.dto';
import { StoreService } from '../services/store.service';

@Controller('stores')
@UseGuards(AppKeyGuard)
export class StoresController {
  constructor(private readonly stores: StoreService) {}

  @Get()
  @Message('Stores retrieved successfully.')
  async list(@Query('category', new ParseIntPipe({ optional: true })) categoryId?: number) {
    return (await this.stores.list(categoryId)).map((store) => this.stores.snapshot(store));
  }

  @Get(':id')
  @Message('Store retrieved successfully.')
  async get(@Param('id', ParseIntPipe) id: number) { return this.stores.snapshot(await this.stores.require(id)); }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.PlatformAdmin)
  @Message('Store created successfully.')
  async create(@Body() dto: CreateStoreDto) { return this.stores.snapshot(await this.stores.create(dto)); }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.PlatformAdmin)
  @Message('Store updated successfully.')
  async update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateStoreDto) { return this.stores.snapshot(await this.stores.update(await this.stores.require(id), dto)); }

  @Get(':id/profile')
  @UseGuards(JwtAuthGuard)
  async profile(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: JwtPayload) {
    await this.stores.verifyUser(id, user.sub);
    return this.stores.snapshot(await this.stores.require(id));
  }
}
