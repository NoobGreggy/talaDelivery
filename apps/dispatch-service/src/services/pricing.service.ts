import { Injectable, Logger } from '@nestjs/common';
import { DomainError, isAppError } from '@taladelivery/common';
import { DeliveryZoneStatus } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeliveryZone } from '../entities/delivery-zone.entity';
import { DispatchSettingsService } from './dispatch-settings.service';
import { RoadDistanceService } from './road-distance.service';
import { ZoneBoundaryService } from './zone-boundary.service';
import { moneyString, twoDecimal } from '../common/format.util';

export interface PricingBreakdown {
  deliveryFee: string;
  distanceKm: string;
  billableDistanceKm: string;
  distanceMethod: string;
  zone: DeliveryZone;
}

/**
 * Mirrors Laravel PricingService exactly (formulas + error strings).
 * Money is produced as two-decimal strings for persistence/API.
 */
@Injectable()
export class PricingService {
  private readonly logger = new Logger(PricingService.name);

  constructor(
    private readonly roadDistance: RoadDistanceService,
    private readonly boundaries: ZoneBoundaryService,
    private readonly settings: DispatchSettingsService,
    @InjectRepository(DeliveryZone)
    private readonly zones: Repository<DeliveryZone>,
  ) {}

  async calculate(
    pickupLat: number | null,
    pickupLng: number | null,
    deliveryLat: number | null,
    deliveryLng: number | null,
    city?: string | null,
    province?: string | null,
    allowedZoneIds?: number[],
  ): Promise<PricingBreakdown> {
    if (
      pickupLat === null ||
      pickupLng === null ||
      deliveryLat === null ||
      deliveryLng === null
    ) {
      throw new DomainError(
        'A valid pickup and delivery location is required to place an order.',
      );
    }

    const zone = await this.resolveZone(city, province, deliveryLat, deliveryLng, allowedZoneIds);

    return this.calculateForZone(zone, pickupLat, pickupLng, deliveryLat, deliveryLng);
  }

  async calculateForZone(
    zone: DeliveryZone,
    pickupLat: number,
    pickupLng: number,
    deliveryLat: number,
    deliveryLng: number,
    distanceMethod?: string | null,
  ): Promise<PricingBreakdown> {
    const method = distanceMethod ?? (await this.settings.current()).distanceMethod;

    const distanceKm =
      method === 'ROAD_ROUTE'
        ? await this.roadDistance.distanceKm(pickupLat, pickupLng, deliveryLat, deliveryLng)
        : this.distanceKm(pickupLat, pickupLng, deliveryLat, deliveryLng);

    if (distanceKm === null) {
      throw new DomainError('Road distance is temporarily unavailable. Please try again.');
    }

    const maximumDistance =
      zone.maximumDeliveryKm === null ? null : Number.parseFloat(zone.maximumDeliveryKm);
    if (maximumDistance !== null && distanceKm > maximumDistance) {
      throw new DomainError(
        `Delivery distance exceeds this zone's ${maximumDistance} km limit.`,
      );
    }

    const baseFee = Number.parseFloat(zone.baseFee ?? '0') || 0;
    const includedKm = Number.parseFloat(zone.includedKm ?? '0') || 0;
    const extraPerKm = Number.parseFloat(zone.extraFeePerKm ?? '0') || 0;
    const roundingKm = Math.max(0.1, Number.parseFloat(zone.distanceRoundingKm ?? '0.1'));
    const billableDistanceKm =
      Math.ceil(distanceKm / roundingKm - 0.0000001) * roundingKm;

    const extraKm = Math.max(0.0, billableDistanceKm - includedKm);
    let deliveryFee = baseFee + extraPerKm * extraKm;
    if (zone.maximumDeliveryFee !== null) {
      deliveryFee = Math.min(deliveryFee, Number.parseFloat(zone.maximumDeliveryFee));
    }

    return {
      deliveryFee: moneyString(Math.round(deliveryFee * 100) / 100),
      distanceKm: twoDecimal(Math.round(distanceKm * 100) / 100),
      billableDistanceKm: twoDecimal(Math.round(billableDistanceKm * 100) / 100),
      distanceMethod: method,
      zone,
    };
  }

  async resolveZone(
    city: string | null | undefined,
    province: string | null | undefined,
    deliveryLat?: number | null,
    deliveryLng?: number | null,
    allowedZoneIds?: number[],
  ): Promise<DeliveryZone> {
    if (allowedZoneIds !== undefined && !allowedZoneIds.length) throw new DomainError('This store has no assigned delivery zones.');
    const normalizedCity = squish(city ?? '').toLowerCase();
    if (normalizedCity === '') {
      throw new DomainError('A city is required to calculate the delivery fee.');
    }

    const normalizedProvince = squish(province ?? '').toLowerCase();
    if (normalizedProvince === '') {
      throw new DomainError('A province is required to calculate the delivery fee.');
    }

    const baseCity = normalizedCity.endsWith(' city')
      ? normalizedCity.slice(0, -' city'.length)
      : normalizedCity;
    const acceptedCityNames = [...new Set([baseCity, `${baseCity} city`])];

    const now = new Date();
    const query = this.zones
      .createQueryBuilder('zone')
      .where('zone.status = :status', { status: DeliveryZoneStatus.Active })
      .andWhere('(zone.effective_from IS NULL OR zone.effective_from <= :now)', { now })
      .orderBy('zone.id', 'ASC');
    if (allowedZoneIds !== undefined) query.andWhere('zone.id IN (:...allowedZoneIds)', { allowedZoneIds });
    const zones = await query.getMany();

    if (
      deliveryLat !== null &&
      deliveryLat !== undefined &&
      deliveryLng !== null &&
      deliveryLng !== undefined
    ) {
      const boundaryMatch = zones.find(
        (zone): boolean =>
          zone.boundaryGeoJson !== null &&
          this.boundaries.covers(zone.boundaryGeoJson, deliveryLat, deliveryLng),
      );
      if (boundaryMatch !== undefined) {
        return boundaryMatch;
      }
    }

    const matched = zones.find((zone): boolean => {
      if (zone.boundaryGeoJson !== null) {
        return false;
      }
      const zoneCity = squish(zone.city ?? '').toLowerCase();
      const zoneProvince = squish(zone.province ?? '').toLowerCase();
      return acceptedCityNames.includes(zoneCity) && zoneProvince === normalizedProvince;
    });

    if (matched === undefined) {
      throw new DomainError(allowedZoneIds !== undefined ? 'This store does not deliver to the selected address.' : 'Delivery is not available in the selected city.');
    }

    return matched;
  }

  /** Haversine straight-line distance in kilometers (Laravel PricingService::distanceKm). */
  distanceKm(
    fromLat?: number | null,
    fromLng?: number | null,
    toLat?: number | null,
    toLng?: number | null,
  ): number {
    if (
      fromLat === null ||
      fromLng === null ||
      toLat === null ||
      toLng === null ||
      fromLat === undefined ||
      fromLng === undefined ||
      toLat === undefined ||
      toLng === undefined
    ) {
      return 0.0;
    }

    const earthRadiusKm = 6371.0;
    const toRad = (deg: number): number => (deg * Math.PI) / 180;

    const dLat = toRad(toLat - fromLat);
    const dLng = toRad(toLng - fromLng);

    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(fromLat)) * Math.cos(toRad(toLat)) * Math.sin(dLng / 2) ** 2;

    return earthRadiusKm * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
  }
}

export function squish(value: string): string {
  return value.replace(/\s+/g, ' ').trim();
}

/** Re-exported for callers that translate expected business failures to 422. */
export { isAppError };
