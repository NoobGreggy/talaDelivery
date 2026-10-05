import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { DomainError } from '@taladelivery/common';
import { In, Repository } from 'typeorm';
import { DeliveryZone } from '../../entities/delivery-zone.entity';

@Controller('internal/delivery-zones')
@UseGuards(ServiceAuthGuard)
export class InternalDeliveryZonesController {
  constructor(@InjectRepository(DeliveryZone) private readonly zones: Repository<DeliveryZone>) {}
  @Get('batch')
  async batch(@Query('ids') raw = '') {
    const ids = raw ? raw.split(',').map(Number) : [];
    if (ids.length > 50 || ids.some((id) => !Number.isInteger(id) || id < 1)) throw new DomainError('Invalid delivery zone IDs.');
    if (!ids.length) return [];
    return (await this.zones.findBy({ id: In(ids) })).map((zone) => ({ id: zone.id, name: zone.name, status: zone.status }));
  }
}
