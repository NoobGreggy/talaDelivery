import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DomainError, ServiceClientFactory } from '@taladelivery/common';
import { Repository } from 'typeorm';
import { Store } from '../entities/store.entity';

@Injectable()
export class StoreDeliveryZonesService {
  constructor(@InjectRepository(Store) private readonly stores: Repository<Store>, private readonly factory: ServiceClientFactory) {}
  async assign(storeId: number, ids: number[]): Promise<void> {
    // Dispatch owns zone existence/status. Never guess coverage from the store's city.
    const zones = ids.length ? await this.factory.create('DISPATCH_SERVICE_URL')
      .get<Array<{ id: number; status: string }>>(`/internal/delivery-zones/batch?ids=${ids.join(',')}`) : [];
    if (zones.length !== ids.length || ids.some((id) => !zones.some((zone) => zone.id === id))) {
      throw new DomainError('One or more selected delivery zones no longer exist.');
    }
    await this.stores.manager.transaction(async (manager) => {
      const store = await manager.getRepository(Store).createQueryBuilder('store')
        .setLock('pessimistic_write').where('store.id = :id', { id: storeId }).getOne();
      if (!store) throw new NotFoundException('Store not found.');
      if (zones.some((zone) => zone.status !== 'ACTIVE' && !(store.deliveryZoneIds ?? []).includes(zone.id))) {
        throw new DomainError('Only active delivery zones can be newly assigned to a store.');
      }
      await manager.getRepository(Store).update({ id: storeId }, { deliveryZoneIds: [...ids].sort((a, b) => a - b) });
    });
  }
}
