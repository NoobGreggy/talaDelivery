import { Body, Controller, Delete, Get, NotFoundException, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { AppKeyGuard, CurrentUser, JwtAuthGuard, JwtPayload, Roles, RolesGuard } from '@taladelivery/auth';
import { Role } from '@taladelivery/contracts';
import { Message } from '@taladelivery/common';
import { IsBoolean, IsLatitude, IsLongitude, IsOptional, IsString, Length } from 'class-validator';
import { Repository } from 'typeorm';
import { CustomerAddress } from '../entities/customer-address.entity';

export class CustomerAddressDto {
  @IsString() @Length(1, 160) recipient_name: string;
  @IsString() @Length(1, 40) phone: string;
  @IsString() @Length(1, 500) address_line: string;
  @IsString() @Length(1, 120) city: string;
  @IsString() @Length(1, 120) province: string;
  @IsOptional() @IsString() @Length(0, 80) label?: string;
  @IsOptional() @IsString() @Length(0, 120) barangay?: string;
  @IsOptional() @IsString() @Length(0, 20) postal_code?: string;
  @IsOptional() @IsString() @Length(0, 1000) notes?: string;
  @IsOptional() @IsLatitude() latitude?: number;
  @IsOptional() @IsLongitude() longitude?: number;
  @IsOptional() @IsBoolean() is_default?: boolean;
}

@Controller('addresses')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.Customer)
export class AddressesController {
  constructor(@InjectRepository(CustomerAddress) private readonly addresses: Repository<CustomerAddress>) {}
  @Get() @Message('Addresses retrieved.')
  async list(@CurrentUser() user: JwtPayload) {
    return (await this.addresses.find({ where: { userId: user.sub }, order: { is_default: 'DESC', id: 'DESC' } }))
      .map((address) => this.resource(address));
  }
  @Post() @Message('Address saved.')
  async create(@CurrentUser() user: JwtPayload, @Body() dto: CustomerAddressDto) { return this.save(user.sub, dto); }
  @Put(':id') @Message('Address updated.')
  async update(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number, @Body() dto: CustomerAddressDto) {
    return this.save(user.sub, dto, id);
  }
  @Delete(':id') @Message('Address deleted.')
  async remove(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const result = await this.addresses.delete({ id, userId: user.sub });
    if (!result.affected) throw new NotFoundException('Address not found.');
    return null;
  }
  private async save(userId: number, dto: CustomerAddressDto, id?: number) {
    return this.addresses.manager.transaction(async (manager) => {
      await manager.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
      const repo = manager.getRepository(CustomerAddress);
      const address = id == null ? repo.create({ userId }) : await repo.findOneBy({ id, userId });
      if (!address) throw new NotFoundException('Address not found.');
      if (dto.is_default) await repo.update({ userId, is_default: true }, { is_default: false });
      Object.assign(address, dto, { userId, is_default: dto.is_default ?? address.is_default ?? false,
        latitude: dto.latitude == null ? null : String(dto.latitude), longitude: dto.longitude == null ? null : String(dto.longitude) });
      return this.resource(await repo.save(address));
    });
  }
  private resource(address: CustomerAddress) {
    const { userId: _userId, ...resource } = address;
    return resource;
  }
}
