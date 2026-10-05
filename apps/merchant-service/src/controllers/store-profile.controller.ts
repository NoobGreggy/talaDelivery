import { Body, Controller, Get, Headers, NotFoundException, Put, UseGuards } from '@nestjs/common';
import { AppKeyGuard, CurrentUser, JwtAuthGuard, Roles, RolesGuard, JwtPayload } from '@taladelivery/auth';
import { Message } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { IsEmail, IsOptional, IsString, Length, Matches } from 'class-validator';
import { StoreService } from '../services/store.service';
import { Store } from '../entities/store.entity';

export class StoreProfileDto {
  @IsOptional() @IsString() @Length(1, 160) name?: string;
  @IsOptional() @IsString() @Length(0, 2000) description?: string;
  @IsOptional() @IsEmail() @Length(1, 254) email?: string;
  @IsOptional() @IsString() @Length(1, 40) phone?: string;
  @IsOptional() @IsString() @Length(1, 1000) address?: string;
  @IsOptional() @Matches(/^([01]\d|2[0-3]):[0-5]\d$/) opening_time?: string;
  @IsOptional() @Matches(/^([01]\d|2[0-3]):[0-5]\d$/) closing_time?: string;
}

@Controller('store/profile')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.StoreAdmin)
export class StoreProfileController {
  constructor(private readonly stores: StoreService) {}
  private async owned(userId: number, selected?: string) {
    const store = await this.stores.forUser(userId, selected);
    if (!store) throw new NotFoundException('Store membership not found.');
    return store;
  }
  @Get() @Message('Store profile retrieved.')
  async show(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string) {
    return this.resource(await this.owned(user.sub, selected));
  }
  @Put() @Message('Store profile updated.')
  async update(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Body() dto: StoreProfileDto) {
    const store = await this.owned(user.sub, selected);
    if (dto.description !== undefined) store.description = dto.description;
    if (dto.email !== undefined) store.email = dto.email;
    const hours = { ...(store.openingHours ?? {}) };
    if (dto.opening_time || dto.closing_time) {
      for (const day of ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']) {
        hours[day] = { open: dto.opening_time ?? hours[day]?.open ?? '09:00',
          close: dto.closing_time ?? hours[day]?.close ?? '17:00', isClosed: hours[day]?.isClosed ?? false };
      }
    }
    const updated = await this.stores.update(store, { name: dto.name ?? store.name,
      phone: dto.phone ?? store.phone ?? undefined, address: dto.address ?? store.address ?? undefined,
      openingHours: hours });
    return this.resource(updated);
  }
  private resource(store: Store) {
    return { ...this.stores.snapshot(store), description: store.description, email: store.email,
      opening_time: store.openingHours?.monday?.open,
      closing_time: store.openingHours?.monday?.close, created_at: store.createdAt.toISOString() };
  }
}
