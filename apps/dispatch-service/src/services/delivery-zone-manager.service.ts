import { Injectable } from '@nestjs/common';
import { ValidationError } from '@taladelivery/common';
import { DeliveryZoneStatus } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { DeliveryZone, type GeoJsonBoundary } from '../entities/delivery-zone.entity';
import { DeliveryZoneRevision } from '../entities/delivery-zone-revision.entity';
import { ZoneBoundaryService } from './zone-boundary.service';
import { squish } from './pricing.service';

export interface ZoneInput {
  talaCoinsPercent?: string;
  name?: string;
  city?: string | null;
  province?: string | null;
  boundaryGeoJson?: GeoJsonBoundary | null;
  baseFee?: string;
  includedKm?: string;
  maximumDeliveryKm?: string | null;
  extraFeePerKm?: string;
  maximumDeliveryFee?: string | null;
  distanceRoundingKm?: string;
  effectiveFrom?: Date | null;
  status?: string;
  /** Internal audit fields (not accepted from the API). */
  createdBy?: number | null;
  updatedBy?: number | null;
}

const ZONE_SNAPSHOT_FIELDS = [
  'talaCoinsPercent',
  'name',
  'city',
  'province',
  'boundaryGeoJson',
  'baseFee',
  'includedKm',
  'maximumDeliveryKm',
  'extraFeePerKm',
  'maximumDeliveryFee',
  'distanceRoundingKm',
  'effectiveFrom',
  'status',
] as const;

/**
 * Mirrors Laravel DeliveryZoneManager (CRUD + revision audit + publish rules:
 * one city-wide fallback per city/province, no overlapping boundaries).
 */
@Injectable()
export class DeliveryZoneManager {
  constructor(
    private readonly boundaries: ZoneBoundaryService,
    private readonly dataSource: DataSource,
    @InjectRepository(DeliveryZone)
    private readonly zones: Repository<DeliveryZone>,
    @InjectRepository(DeliveryZoneRevision)
    private readonly revisions: Repository<DeliveryZoneRevision>,
  ) {}

  async create(input: ZoneInput, actorId: number): Promise<DeliveryZone> {
    return this.dataSource.transaction(
      async (manager): Promise<DeliveryZone> => {
        const attributes = this.normalize(input);
        attributes.createdBy = actorId;
        attributes.updatedBy = actorId;
        await this.assertCanPublish(attributes, null);

        const zone = await manager.getRepository(DeliveryZone).save(
          manager.getRepository(DeliveryZone).create({
            ...attributes,
            status: attributes.status ?? DeliveryZoneStatus.Draft,
          }),
        );

        await manager.getRepository(DeliveryZoneRevision).save(
          manager.getRepository(DeliveryZoneRevision).create({
            deliveryZoneId: zone.id,
            userId: actorId,
            action: 'CREATED',
            after: this.snapshot(zone),
          }),
        );

        return manager.getRepository(DeliveryZone).findOneOrFail({
          where: { id: zone.id },
          cache: false,
        });
      },
    );
  }

  async update(
    zone: DeliveryZone,
    input: ZoneInput,
    actorId: number,
  ): Promise<DeliveryZone> {
    return this.dataSource.transaction(
      async (manager): Promise<DeliveryZone> => {
        const before = this.snapshot(zone);
        const attributes = this.normalize(input);
        attributes.updatedBy = actorId;

        const candidate = { ...zone, ...attributes };
        await this.assertCanPublish(candidate as DeliveryZone, zone.id);

        await manager.getRepository(DeliveryZone).update(
          { id: zone.id },
          attributes as Partial<DeliveryZone>,
        );
        const updated = await manager
          .getRepository(DeliveryZone)
          .findOneOrFail({ where: { id: zone.id } });

        await manager.getRepository(DeliveryZoneRevision).save(
          manager.getRepository(DeliveryZoneRevision).create({
            deliveryZoneId: zone.id,
            userId: actorId,
            action: 'UPDATED',
            before,
            after: this.snapshot(updated),
          }),
        );

        return updated;
      },
    );
  }

  async archive(zone: DeliveryZone, actorId: number): Promise<DeliveryZone> {
    return this.dataSource.transaction(
      async (manager): Promise<DeliveryZone> => {
        const before = this.snapshot(zone);
        await manager.getRepository(DeliveryZone).update(
          { id: zone.id },
          { status: DeliveryZoneStatus.Archived, updatedBy: actorId },
        );
        const updated = await manager
          .getRepository(DeliveryZone)
          .findOneOrFail({ where: { id: zone.id } });

        await manager.getRepository(DeliveryZoneRevision).save(
          manager.getRepository(DeliveryZoneRevision).create({
            deliveryZoneId: zone.id,
            userId: actorId,
            action: 'ARCHIVED',
            before,
            after: this.snapshot(updated),
          }),
        );

        return updated;
      },
    );
  }

  private normalize(input: ZoneInput): ZoneInput {
    const result: ZoneInput = { ...input };
    for (const field of ['name', 'city', 'province'] as const) {
      if (typeof result[field] === 'string') {
        result[field] = squish(result[field] as string);
      }
    }
    return result;
  }

  private async assertCanPublish(
    attributes: ZoneInput,
    currentId: number | null,
  ): Promise<void> {
    const statusValue =
      attributes.status ?? (currentId === null ? DeliveryZoneStatus.Draft : undefined);
    if (statusValue !== DeliveryZoneStatus.Active) {
      return;
    }

    const city = String(attributes.city ?? '');
    const province = String(attributes.province ?? '');
    const boundary = attributes.boundaryGeoJson ?? null;

    if (boundary === null || boundary === undefined) {
      const normalizedCity = squish(city).toLowerCase();
      const baseCity = normalizedCity.endsWith(' city')
        ? normalizedCity.slice(0, -' city'.length)
        : normalizedCity;
      const acceptedCityNames = [baseCity, `${baseCity} city`];

      const duplicate = await this.zones
        .createQueryBuilder('zone')
        .where('zone.status = :status', { status: DeliveryZoneStatus.Active })
        .andWhere('zone.boundary_geojson IS NULL')
        .andWhere('LOWER(TRIM(zone.city)) IN (:...cities)', {
          cities: acceptedCityNames,
        })
        .andWhere('LOWER(TRIM(zone.province)) = :province', {
          province: province.toLowerCase(),
        })
        .andWhere(currentId !== null ? 'zone.id != :currentId' : '1 = 1', {
          currentId: currentId ?? 0,
        })
        .getExists();

      if (duplicate) {
        throw new ValidationError('The given data was invalid.', {
          city: ['Only one active city-wide fallback zone is allowed for the same city and province.'],
        });
      }
      return;
    }

    const activeBoundaryZones = await this.zones.find({
      where: { status: DeliveryZoneStatus.Active },
      select: ['id', 'boundaryGeoJson'],
    });

    const overlap = activeBoundaryZones.find(
      (zone): boolean =>
        zone.id !== currentId &&
        zone.boundaryGeoJson !== null &&
        this.boundaries.overlaps(boundary, zone.boundaryGeoJson),
    );

    if (overlap !== undefined) {
      throw new ValidationError('The given data was invalid.', {
        boundary_geojson: [`The coverage boundary overlaps active zone #${overlap.id}.`],
      });
    }
  }

  private snapshot(zone: DeliveryZone): Record<string, unknown> {
    const snapshot: Record<string, unknown> = {};
    for (const field of ZONE_SNAPSHOT_FIELDS) {
      const value = (zone as unknown as Record<string, unknown>)[field];
      if (value !== undefined) {
        snapshot[field] = value;
      }
    }
    return snapshot;
  }
}
