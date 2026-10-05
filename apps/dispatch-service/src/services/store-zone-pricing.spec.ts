import { PricingService } from './pricing.service';
import { ZoneBoundaryService } from './zone-boundary.service';

function harness() {
  const rows = [
    { id: 1, status: 'ACTIVE', city: 'Cauayan', province: 'Isabela', boundaryGeoJson: null, effectiveFrom: null },
    { id: 2, status: 'ARCHIVED', city: 'Makati', province: 'Metro Manila', boundaryGeoJson: null, effectiveFrom: null },
    { id: 3, status: 'ACTIVE', city: 'Cauayan', province: 'Isabela', boundaryGeoJson: null, effectiveFrom: new Date('2999-01-01') },
  ];
  let allowed: number[] | undefined;
  const query: any = { where: jest.fn(), andWhere: jest.fn(), orderBy: jest.fn(),
    getMany: jest.fn(async () => rows.filter((zone) => zone.status === 'ACTIVE' && (!zone.effectiveFrom || zone.effectiveFrom <= new Date()) && (allowed === undefined || allowed.includes(zone.id)))) };
  query.where.mockReturnValue(query); query.orderBy.mockReturnValue(query);
  query.andWhere.mockImplementation((sql: string, parameters: any) => { if (sql.includes('allowedZoneIds')) allowed = parameters.allowedZoneIds; return query; });
  const service = new PricingService({} as any, new ZoneBoundaryService(), {} as any, { createQueryBuilder: () => query } as any);
  return { service, query };
}
describe('Store-scoped zone coverage', () => {
  it('limits coverage to assigned zone IDs before matching', async () => {
    const h = harness(); const zone = await h.service.resolveZone('Cauayan', 'Isabela', 16.9, 121.7, [1]);
    expect(zone.id).toBe(1);
    expect(h.query.andWhere).toHaveBeenCalledWith('zone.id IN (:...allowedZoneIds)', { allowedZoneIds: [1] });
  });
  it('does not fall back to another store zone covering the same city', async () => {
    await expect(harness().service.resolveZone('Cauayan', 'Isabela', 16.9, 121.7, [2])).rejects.toThrow('does not deliver');
  });
  it('blocks stores with no assignments', async () => {
    await expect(harness().service.resolveZone('Cauayan', 'Isabela', 16.9, 121.7, [])).rejects.toThrow('no assigned');
  });
  it('ignores inactive and future-effective assigned zones', async () => {
    await expect(harness().service.resolveZone('Cauayan', 'Isabela', 16.9, 121.7, [2, 3])).rejects.toThrow('does not deliver');
  });
});
