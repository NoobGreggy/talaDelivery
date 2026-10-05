import { validate } from 'class-validator';
import { StoreDeliveryZonesService } from './store-delivery-zones.service';
import { StoreDeliveryZonesDto } from '../dto/store-delivery-zones.dto';
function harness(existing: number[] = [], zones = [{ id: 1, status: 'ACTIVE' }, { id: 2, status: 'ACTIVE' }], exists = true) {
  const query: any = { setLock: jest.fn(), where: jest.fn(), getOne: jest.fn().mockResolvedValue(exists ? { id: 7, deliveryZoneIds: existing } : null) };
  query.setLock.mockReturnValue(query); query.where.mockReturnValue(query);
  const repository = { createQueryBuilder: () => query, update: jest.fn() };
  const manager = { getRepository: () => repository };
  const stores: any = { manager: { transaction: async (callback: any) => callback(manager) } };
  const get = jest.fn().mockResolvedValue(zones);
  const factory: any = { create: jest.fn(() => ({ get })) };
  return { service: new StoreDeliveryZonesService(stores, factory), repository, factory, get };
}
describe('Store delivery zone assignments', () => {
  it('saves multiple existing active zones only to the requested store', async () => {
    const h = harness(); await h.service.assign(7, [2, 1]);
    expect(h.get).toHaveBeenCalledWith('/internal/delivery-zones/batch?ids=2,1');
    expect(h.repository.update).toHaveBeenCalledWith({ id: 7 }, { deliveryZoneIds: [1, 2] });
  });
  it('rejects nonexistent zone IDs before writing', async () => {
    const h = harness(); await expect(h.service.assign(7, [1, 9])).rejects.toThrow('no longer exist');
    expect(h.repository.update).not.toHaveBeenCalled();
  });
  it('rejects newly assigned inactive zones', async () => {
    const h = harness([], [{ id: 2, status: 'ARCHIVED' }]);
    await expect(h.service.assign(7, [2])).rejects.toThrow('Only active');
    expect(h.repository.update).not.toHaveBeenCalled();
  });
  it('preserves existing inactive assignments without permitting new inactive ones', async () => {
    const h = harness([2], [{ id: 2, status: 'ARCHIVED' }]); await h.service.assign(7, [2]);
    expect(h.repository.update).toHaveBeenCalledWith({ id: 7 }, { deliveryZoneIds: [2] });
  });
  it('clears assignments without calling another service', async () => {
    const h = harness([2]); await h.service.assign(7, []);
    expect(h.factory.create).not.toHaveBeenCalled();
    expect(h.repository.update).toHaveBeenCalledWith({ id: 7 }, { deliveryZoneIds: [] });
  });
  it('rejects nonexistent stores', async () => {
    const h = harness([], [], false); await expect(h.service.assign(7, [])).rejects.toThrow('Store not found');
  });
  it('rejects duplicate, negative and excessively large zone ID lists', async () => {
    for (const ids of [[1, 1], [-1], Array.from({ length: 51 }, (_, index) => index + 1)]) {
      expect((await validate(Object.assign(new StoreDeliveryZonesDto(), { delivery_zone_ids: ids }))).length).toBeGreaterThan(0);
    }
    expect(await validate(Object.assign(new StoreDeliveryZonesDto(), { delivery_zone_ids: [] }))).toEqual([]);
  });
});
