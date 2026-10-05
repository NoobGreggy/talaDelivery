import { DomainError } from '@taladelivery/common';
import {
  DeliveryZoneStatus,
  DistanceMethod,
} from '@taladelivery/contracts';
import { Repository } from 'typeorm';
import { DeliveryZone, type GeoJsonBoundary } from '../entities/delivery-zone.entity';
import { DispatchSettingsService } from './dispatch-settings.service';
import { PricingService } from './pricing.service';
import { RoadDistanceService } from './road-distance.service';
import { ZoneBoundaryService } from './zone-boundary.service';

function makeZone(overrides: Partial<DeliveryZone> = {}): DeliveryZone {
  return {
    id: 1,
    name: 'Makati',
    city: 'Makati',
    province: 'Metro Manila',
    boundaryGeoJson: null,
    baseFee: '50.00',
    includedKm: '3.00',
    maximumDeliveryKm: '20.00',
    extraFeePerKm: '15.00',
    maximumDeliveryFee: '250.00',
    distanceRoundingKm: '0.1',
    effectiveFrom: new Date('2026-01-01T00:00:00.000Z'),
    status: DeliveryZoneStatus.Active,
    ...overrides,
  } as DeliveryZone;
}

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
  getMany: jest.Mock;
} {
  const chain: {
    where: jest.Mock;
    andWhere: jest.Mock;
    orderBy: jest.Mock;
    getMany: jest.Mock;
  } = {
    where: jest.fn(() => chain),
    andWhere: jest.fn(() => chain),
    orderBy: jest.fn(() => chain),
    getMany: jest.fn(async () => finalValue),
  };
  return chain;
}

function createService(): {
  service: PricingService;
  roadDistance: { distanceKm: jest.Mock };
} {
  const roadDistance = { distanceKm: jest.fn(async () => null) };
  const settings = {
    current: jest.fn(async () => ({ distanceMethod: DistanceMethod.StraightLine })),
  } as unknown as DispatchSettingsService;
  const zones = {} as unknown as Repository<DeliveryZone>;
  const service = new PricingService(
    roadDistance as unknown as RoadDistanceService,
    new ZoneBoundaryService(),
    settings,
    zones,
  );
  return { service, roadDistance };
}

describe('PricingService.calculateForZone', () => {
  it('rounds the billable distance up to the nearest 100m increment', async () => {
    const { service, roadDistance } = createService();
    roadDistance.distanceKm.mockResolvedValue(3.05);

    const result = await service.calculateForZone(
      makeZone(),
      14.59,
      120.98,
      14.6,
      120.99,
      DistanceMethod.RoadRoute,
    );

    expect(result.distanceKm).toBe('3.05');
    expect(result.billableDistanceKm).toBe('3.10');
    // base 50 + 15/km for the 0.10 km above the 3.00 km included distance
    expect(result.deliveryFee).toBe('51.50');
    expect(result.distanceMethod).toBe(DistanceMethod.RoadRoute);
  });

  it('does not charge for distance inside the included kilometres', async () => {
    const { service, roadDistance } = createService();
    roadDistance.distanceKm.mockResolvedValue(3.0);

    const result = await service.calculateForZone(
      makeZone(),
      14.59,
      120.98,
      14.6,
      120.99,
      DistanceMethod.RoadRoute,
    );

    expect(result.billableDistanceKm).toBe('3.00');
    expect(result.deliveryFee).toBe('50.00');
  });

  it('caps the fee at the zone maximum delivery fee', async () => {
    const { service, roadDistance } = createService();
    roadDistance.distanceKm.mockResolvedValue(20.0);

    const result = await service.calculateForZone(
      makeZone({ maximumDeliveryFee: '250.00' }),
      14.59,
      120.98,
      14.6,
      120.99,
      DistanceMethod.RoadRoute,
    );

    expect(result.billableDistanceKm).toBe('20.00');
    // 50 + 15 * 17 = 305 -> capped
    expect(result.deliveryFee).toBe('250.00');
  });

  it('rejects distances beyond the zone maximum', async () => {
    const { service, roadDistance } = createService();
    roadDistance.distanceKm.mockResolvedValue(12.0);

    await expect(
      service.calculateForZone(
        makeZone({ maximumDeliveryKm: '10.00' }),
        14.59,
        120.98,
        14.6,
        120.99,
        DistanceMethod.RoadRoute,
      ),
    ).rejects.toThrow("Delivery distance exceeds this zone's 10 km limit.");
  });

  it('throws a business error when road distance routing is unavailable', async () => {
    const { service } = createService();

    await expect(
      service.calculateForZone(
        makeZone(),
        14.59,
        120.98,
        14.6,
        120.99,
        DistanceMethod.RoadRoute,
      ),
    ).rejects.toThrow('Road distance is temporarily unavailable. Please try again.');
  });

  it('uses straight-line distance when configured and never calls the router', async () => {
    const { service, roadDistance } = createService();
    roadDistance.distanceKm.mockResolvedValue(99.0);

    const result = await service.calculateForZone(
      makeZone(),
      14.5995,
      120.9842,
      14.6015,
      120.9872,
    );

    expect(roadDistance.distanceKm).not.toHaveBeenCalled();
    expect(result.distanceMethod).toBe(DistanceMethod.StraightLine);
    expect(result.deliveryFee).toBe('50.00'); // short hop inside included 3 km
  });
});

describe('PricingService.calculate', () => {
  it('requires pickup and delivery coordinates', async () => {
    const { service } = createService();
    await expect(
      service.calculate(null, 120.98, 14.6, 120.99, 'Makati', 'Metro Manila'),
    ).rejects.toThrow(
      'A valid pickup and delivery location is required to place an order.',
    );
  });
});

describe('PricingService.distanceKm (haversine)', () => {
  const { service } = createService();

  it('returns zero for identical coordinates', () => {
    expect(service.distanceKm(14.6, 121.0, 14.6, 121.0)).toBe(0);
  });

  it('approximates one degree of longitude at the equator', () => {
    expect(service.distanceKm(0, 0, 0, 1)).toBeCloseTo(111.19, 1);
  });

  it('is symmetric', () => {
    const forward = service.distanceKm(14.5995, 120.9842, 14.6015, 120.9872);
    const reverse = service.distanceKm(14.6015, 120.9872, 14.5995, 120.9842);
    expect(forward).toBe(reverse);
    expect(forward).toBeGreaterThan(0);
  });

  it('treats missing coordinates as zero distance', () => {
    expect(service.distanceKm(null, null, 14.6, 121.0)).toBe(0);
  });
});

describe('PricingService.resolveZone', () => {
  function zonesRepo(zones: DeliveryZone[]): Repository<DeliveryZone> {
    return {
      createQueryBuilder: jest.fn(() => builderChain(zones)),
    } as unknown as Repository<DeliveryZone>;
  }

  function serviceWith(zones: DeliveryZone[]): PricingService {
    const roadDistance = { distanceKm: jest.fn(async () => null) };
    const settings = {
      current: jest.fn(async () => ({ distanceMethod: DistanceMethod.StraightLine })),
    } as unknown as DispatchSettingsService;
    return new PricingService(
      roadDistance as unknown as RoadDistanceService,
      new ZoneBoundaryService(),
      settings,
      zonesRepo(zones),
    );
  }

  it('requires a city', async () => {
    await expect(serviceWith([makeZone()]).resolveZone('', 'Metro Manila')).rejects.toThrow(
      'A city is required to calculate the delivery fee.',
    );
  });

  it('requires a province', async () => {
    await expect(serviceWith([makeZone()]).resolveZone('Makati', '')).rejects.toThrow(
      'A province is required to calculate the delivery fee.',
    );
  });

  it('matches a city-wide fallback zone by city and province', async () => {
    const zone = makeZone();
    const matched = await serviceWith([zone]).resolveZone('Makati', 'Metro Manila');
    expect(matched.id).toBe(zone.id);
  });

  it('treats "My City" as a variant of "My"', async () => {
    const zone = makeZone({ city: 'Quezon City' });
    const matched = await serviceWith([zone]).resolveZone('Quezon', 'Metro Manila');
    expect(matched.id).toBe(zone.id);
  });

  it('prefers a boundary-matching zone over a city-wide fallback', async () => {
    const boundary = makeZone({
      id: 2,
      boundaryGeoJson: square(120.9, 14.5, 121.2, 14.8),
    });
    const fallback = makeZone({ id: 1 });

    const matched = await serviceWith([fallback, boundary]).resolveZone(
      'Makati',
      'Metro Manila',
      14.6,
      121.0,
    );
    expect(matched.id).toBe(boundary.id);
  });

  it('throws when no zone covers the city', async () => {
    await expect(
      serviceWith([makeZone({ city: 'Pasig' })]).resolveZone('Makati', 'Metro Manila'),
    ).rejects.toThrow('Delivery is not available in the selected city.');
  });
});