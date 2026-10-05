import { ValidationError } from '@taladelivery/common';
import { DeliveryZoneStatus } from '@taladelivery/contracts';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { DeliveryZone, type GeoJsonBoundary } from '../entities/delivery-zone.entity';
import { DeliveryZoneRevision } from '../entities/delivery-zone-revision.entity';
import { DeliveryZoneManager, type ZoneInput } from './delivery-zone-manager.service';
import { ZoneBoundaryService } from './zone-boundary.service';

function square(lngMin: number, latMin: number, lngMax: number, latMax: number): GeoJsonBoundary {
  return {
    type: 'Polygon',
    coordinates: [
      [
        [lngMin, latMin],
        [lngMax, latMin],
        [lngMax, latMax],
        [lngMin, latMax],
        [lngMin, latMin],
      ],
    ],
  };
}

function builderChain(finalValue: unknown): {
  where: jest.Mock;
  andWhere: jest.Mock;
  orderBy: jest.Mock;
  getExists: jest.Mock;
  getMany: jest.Mock;
} {
  const chain: {
    where: jest.Mock;
    andWhere: jest.Mock;
    orderBy: jest.Mock;
    getExists: jest.Mock;
    getMany: jest.Mock;
  } = {
    where: jest.fn(() => chain),
    andWhere: jest.fn(() => chain),
    orderBy: jest.fn(() => chain),
    getExists: jest.fn(async () => finalValue),
    getMany: jest.fn(async () => finalValue),
  };
  return chain;
}

interface Harness {
  service: DeliveryZoneManager;
  boundaries: { overlaps: jest.Mock };
  zones: {
    create: jest.Mock;
    save: jest.Mock;
    findOneOrFail: jest.Mock;
    createQueryBuilder: jest.Mock;
    find: jest.Mock;
  };
  revisions: { create: jest.Mock; save: jest.Mock };
  state: { duplicateExists: boolean; savedZone: DeliveryZone | null };
}

function createHarness(): Harness {
  const boundaries: Harness['boundaries'] = { overlaps: jest.fn(() => false) };

  const state = { duplicateExists: false, savedZone: null as DeliveryZone | null };
  const zones = {
    create: jest.fn((zone: Partial<DeliveryZone>) => zone as DeliveryZone),
    save: jest.fn(async (zone: DeliveryZone) => {
      state.savedZone = { ...zone, id: 12 };
      return state.savedZone;
    }),
    findOneOrFail: jest.fn(async () => state.savedZone as DeliveryZone),
    createQueryBuilder: jest.fn(() => builderChain(() => state.duplicateExists)),
    find: jest.fn(async () => []),
  };
  const revisions = {
    create: jest.fn((revision: Partial<DeliveryZoneRevision>) => revision as DeliveryZoneRevision),
    save: jest.fn(async (revision: DeliveryZoneRevision) => revision),
  };
  const manager = {
    getRepository: jest.fn((entity: unknown) => {
      if (entity === DeliveryZone) return zones;
      if (entity === DeliveryZoneRevision) return revisions;
      throw new Error(`unexpected repository for ${String(entity)}`);
    }),
  };
  const dataSource = {
    transaction: jest.fn(
      async (callback: (m: EntityManager) => Promise<unknown>): Promise<unknown> =>
        callback(manager as unknown as EntityManager),
    ),
  };

  const service = new DeliveryZoneManager(
    boundaries as unknown as ZoneBoundaryService,
    dataSource as unknown as DataSource,
    zones as unknown as Repository<DeliveryZone>,
    revisions as unknown as Repository<DeliveryZoneRevision>,
  );

  return {
    service,
    boundaries,
    zones,
    revisions,
    state,
  };
}

const baseInput: ZoneInput = {
  name: 'Makati Core',
  city: 'Makati',
  province: 'Metro Manila',
  baseFee: '50.00',
  includedKm: '3.00',
  extraFeePerKm: '15.00',
  distanceRoundingKm: '0.1',
};

async function rejectionError(
  promise: Promise<unknown>,
): Promise<{ message: string; errors: Record<string, unknown> }> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof ValidationError) {
      return { message: error.message, errors: error.errors ?? {} };
    }
    throw error;
  }
  throw new Error('expected the promise to reject');
}

describe('DeliveryZoneManager.create', () => {
  it('creates a draft zone and records a revision', async () => {
    const h = createHarness();
    const zone = await h.service.create(baseInput, 1);

    expect(zone.id).toBe(12);
    expect(zone.status).toBe(DeliveryZoneStatus.Draft);
    expect(h.zones.save).toHaveBeenCalled();
    expect(h.revisions.save).toHaveBeenCalledWith(
      expect.objectContaining({ deliveryZoneId: 12, action: 'CREATED' }),
    );
  });

  it('rejects a second active city-wide fallback for the same city/province', async () => {
    const h = createHarness();
    h.state.duplicateExists = true;

    const error = await rejectionError(
      h.service.create({ ...baseInput, status: DeliveryZoneStatus.Active }, 1),
    );

    expect(error.message).toBe('The given data was invalid.');
    expect(error.errors.city).toEqual([
      'Only one active city-wide fallback zone is allowed for the same city and province.',
    ]);
  });

  it('rejects an active boundary zone that overlaps an existing active zone', async () => {
    const h = createHarness();
    h.zones.find.mockResolvedValue([
      { id: 2, boundaryGeoJson: square(121.05, 14.55, 121.15, 14.65) },
    ]);
    h.boundaries.overlaps.mockReturnValue(true);

    const error = await rejectionError(
      h.service.create(
        { ...baseInput, status: DeliveryZoneStatus.Active, boundaryGeoJson: square(121.0, 14.5, 121.1, 14.6) },
        1,
      ),
    );

    expect(error.message).toBe('The given data was invalid.');
    expect(error.errors.boundary_geojson).toEqual([
      'The coverage boundary overlaps active zone #2.',
    ]);
  });

  it('allows a draft boundary zone even when it overlaps an active zone', async () => {
    const h = createHarness();
    h.zones.find.mockResolvedValue([
      { id: 2, boundaryGeoJson: square(121.05, 14.55, 121.15, 14.65) },
    ]);

    const zone = await h.service.create(
      { ...baseInput, boundaryGeoJson: square(121.0, 14.5, 121.1, 14.6) },
      1,
    );

    expect(zone.id).toBe(12);
    expect(h.boundaries.overlaps).not.toHaveBeenCalled();
  });
});