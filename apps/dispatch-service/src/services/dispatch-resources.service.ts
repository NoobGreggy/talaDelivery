import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  ALL_TRACKABLE_DELIVERY_STATUSES,
  DeliveryStatus,
  type DeliverySnapshot,
  type RiderProfileSnapshot,
  type StoreSnapshot,
  type UserSnapshot,
} from '@taladelivery/contracts';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { Rider } from '../entities/rider.entity';
import { DeliveryZone } from '../entities/delivery-zone.entity';
import { DeliveryZoneRevision } from '../entities/delivery-zone-revision.entity';
import { RemoteReferencesService, type OrderReference } from './remote-references.service';
import { toIso } from '../common/format.util';

export interface RiderLocationJson {
  latitude: string | null;
  longitude: string | null;
  accuracy_m: string | null;
  heading_deg: string | null;
  speed_mps: string | null;
  recorded_at: string | null;
}

export interface DeliveryResourceJson {
  id: number;
  order_id: number;
  store_id: number;
  status: string;
  rider: UserSnapshot | null;
  rider_location: RiderLocationJson | null;
  pickup_address: string | null;
  pickup_latitude: string | null;
  pickup_longitude: string | null;
  delivery_address: string | null;
  delivery_latitude: string | null;
  delivery_longitude: string | null;
  distance_km: string | null;
  delivery_fee: string | null;
  rider_commission: string | null;
  commission_type: string | null;
  commission_value: string | null;
  cancelled_by: string | null;
  cancellation_reason: string | null;
  assigned_at: string | null;
  accepted_at: string | null;
  picked_up_at: string | null;
  started_at: string | null;
  delivered_at: string | null;
  cancelled_at: string | null;
  created_at: string;
  updated_at: string;
  order: OrderReference | null;
  store: StoreSnapshot | null;
  offers: OfferResourceJson[] | null;
}

export interface OfferResourceJson {
  id: number;
  delivery_id: number;
  rider_id: number;
  status: string;
  offered_at: string | null;
  expires_at: string | null;
  duration_seconds: number | null;
  responded_at: string | null;
  created_at: string;
  delivery: DeliveryResourceJson | null;
}

export interface RiderResourceJson {
  tala_coins_balance: string;
  id: number;
  user_id: number;
  vehicle_type: string;
  vehicle_plate: string | null;
  license_number: string | null;
  requirements: Record<string, unknown> | null;
  is_online: boolean;
  status: string;
  current_latitude: string | null;
  current_longitude: string | null;
  current_location_accuracy: string | null;
  current_location_heading: string | null;
  current_location_speed: string | null;
  current_location_updated_at: string | null;
  completed_deliveries: number;
  total_earnings: string;
  created_at: string;
  user: UserSnapshot | null;
  current_delivery: DeliveryResourceJson | null;
}

export interface ZoneResourceJson {
  tala_coins_percent: string;
  id: number;
  name: string;
  city: string | null;
  province: string | null;
  boundary_geojson: unknown;
  base_fee: string;
  included_km: string;
  maximum_delivery_km: string | null;
  extra_fee_per_km: string;
  maximum_delivery_fee: string | null;
  distance_rounding_km: string;
  effective_from: string | null;
  status: string;
  updated_by: { id: number; name: string } | null;
  revision_count?: number;
  revisions?: Array<{
    id: number;
    action: string;
    before: Record<string, unknown> | null;
    after: Record<string, unknown> | null;
    user: { id: number; name: string } | null;
    created_at: string;
  }>;
  created_at: string;
  updated_at: string;
}

export interface RiderStats {
  completed: number;
  earnings: string;
}

export interface DeliveryResourceHints {
  order?: OrderReference | null;
  store?: StoreSnapshot | null;
  rider?: Rider | null;
  riderUser?: UserSnapshot | null;
  offers?: DeliveryOffer[];
  /** Skip remote lookups that fail (list rendering) */
  skipHydration?: boolean;
}

/**
 * Assembles Laravel-shaped API resources for deliveries, offers, riders and
 * zones. Remote references (order/store/user) are hydrated synchronously.
 *
 * Note: `deliveries.rider_id` references the dispatch `riders` table (not the
 * identity user), so resolving `rider`/`rider_location` always goes through the
 * dispatch Rider row when one is provided.
 */
@Injectable()
export class DispatchResourcesService {
  constructor(
    private readonly refs: RemoteReferencesService,
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
  ) {}

  async deliveryToJson(
    delivery: Delivery,
    hints: DeliveryResourceHints = {},
  ): Promise<DeliveryResourceJson> {
    const order = hints.skipHydration
      ? (hints.order ?? null)
      : (hints.order ?? (await this.refs.orderById(delivery.orderId)));
    const store = hints.skipHydration
      ? (hints.store ?? null)
      : (hints.store ?? (await this.refs.storeById(delivery.storeId)));

    const rider = hints.rider ?? null;
    const riderUser =
      hints.riderUser ?? (rider !== null ? await this.refs.userById(rider.userId) : null);

    const isTrackable = ALL_TRACKABLE_DELIVERY_STATUSES.includes(delivery.status as DeliveryStatus);
    const riderLocation =
      isTrackable && rider !== null
        ? {
            latitude: rider.currentLatitude,
            longitude: rider.currentLongitude,
            accuracy_m: rider.currentLocationAccuracy,
            heading_deg: rider.currentLocationHeading,
            speed_mps: rider.currentLocationSpeed,
            recorded_at: toIso(rider.currentLocationUpdatedAt),
          }
        : null;

    const offers =
      hints.offers === undefined
        ? null
        : await Promise.all(
            hints.offers.map((offer) => this.offerToJson(offer, { skipHydration: true })),
          );

    return {
      id: delivery.id,
      order_id: delivery.orderId,
      store_id: delivery.storeId,
      status: delivery.status,
      rider: riderUser,
      rider_location: riderLocation,
      pickup_address: delivery.pickupAddress,
      pickup_latitude: delivery.pickupLatitude,
      pickup_longitude: delivery.pickupLongitude,
      delivery_address: delivery.deliveryAddress,
      delivery_latitude: delivery.deliveryLatitude,
      delivery_longitude: delivery.deliveryLongitude,
      distance_km: delivery.distanceKm,
      delivery_fee: delivery.deliveryFee,
      rider_commission: delivery.riderCommission,
      commission_type: delivery.commissionType,
      commission_value: delivery.commissionValue,
      cancelled_by: delivery.cancelledBy,
      cancellation_reason: delivery.cancellationReason,
      assigned_at: toIso(delivery.assignedAt),
      accepted_at: toIso(delivery.acceptedAt),
      picked_up_at: toIso(delivery.pickedUpAt),
      started_at: toIso(delivery.startedAt),
      delivered_at: toIso(delivery.deliveredAt),
      cancelled_at: toIso(delivery.cancelledAt),
      created_at: delivery.createdAt.toISOString(),
      updated_at: delivery.updatedAt.toISOString(),
      order,
      store,
      offers,
    };
  }

  async offerToJson(
    offer: DeliveryOffer,
    hints: {
      delivery?: Delivery;
      deliveryJson?: DeliveryResourceJson;
      skipHydration?: boolean;
    } = {},
  ): Promise<OfferResourceJson> {
    const offeredAt = offer.offeredAt ? new Date(offer.offeredAt) : null;
    const expiresAt = offer.expiresAt ? new Date(offer.expiresAt) : null;
    const durationSeconds =
      offeredAt !== null && expiresAt !== null
        ? Math.max(0, Math.floor((expiresAt.getTime() - offeredAt.getTime()) / 1000))
        : null;

    let delivery: DeliveryResourceJson | null = hints.deliveryJson ?? null;
    if (delivery === null && !hints.skipHydration) {
      const row = hints.delivery ?? (await this.deliveries.findOneBy({ id: offer.deliveryId }));
      if (row !== null) delivery = await this.deliveryToJson(row, {});
    }

    return {
      id: offer.id,
      delivery_id: offer.deliveryId,
      rider_id: offer.riderId,
      status: offer.status,
      offered_at: toIso(offeredAt),
      expires_at: toIso(expiresAt),
      duration_seconds: durationSeconds,
      responded_at: toIso(offer.respondedAt),
      created_at: offer.createdAt.toISOString(),
      delivery,
    };
  }

  async riderToJson(
    rider: Rider,
    hints: {
      user?: UserSnapshot | null;
      currentDelivery?: Delivery | null;
      stats?: RiderStats;
    } = {},
  ): Promise<RiderResourceJson> {
    const user = hints.user ?? (await this.refs.userById(rider.userId));
    const currentDelivery = hints.currentDelivery ?? null;
    const stats = hints.stats ?? { completed: 0, earnings: '0.00' };

    return {
      id: rider.id,
      user_id: rider.userId,
      tala_coins_balance: rider.talaCoinsBalance ?? '0.00',
      vehicle_type: rider.vehicleType,
      vehicle_plate: rider.vehiclePlate,
      license_number: rider.licenseNumber,
      requirements: rider.requirements,
      is_online: rider.isOnline,
      status: rider.status,
      current_latitude: rider.currentLatitude,
      current_longitude: rider.currentLongitude,
      current_location_accuracy: rider.currentLocationAccuracy,
      current_location_heading: rider.currentLocationHeading,
      current_location_speed: rider.currentLocationSpeed,
      current_location_updated_at: toIso(rider.currentLocationUpdatedAt),
      completed_deliveries: stats.completed,
      total_earnings: stats.earnings,
      created_at: rider.createdAt.toISOString(),
      user,
      current_delivery:
        currentDelivery === null
          ? null
          : await this.deliveryToJson(currentDelivery, {
              rider,
            }),
    };
  }

  zoneToJson(
    zone: DeliveryZone,
    extras: {
      updatedBy?: { id: number; name: string } | null;
      revisionCount?: number;
      revisions?: DeliveryZoneRevision[];
      revisionUsers?: Map<number, UserSnapshot>;
    } = {},
  ): ZoneResourceJson {
    const json: ZoneResourceJson = {
      id: zone.id,
      name: zone.name,
      city: zone.city,
      province: zone.province,
      boundary_geojson: zone.boundaryGeoJson,
      base_fee: zone.baseFee,
      tala_coins_percent: zone.talaCoinsPercent ?? '0.00',
      included_km: zone.includedKm,
      maximum_delivery_km: zone.maximumDeliveryKm,
      extra_fee_per_km: zone.extraFeePerKm,
      maximum_delivery_fee: zone.maximumDeliveryFee,
      distance_rounding_km: zone.distanceRoundingKm,
      effective_from: toIso(zone.effectiveFrom),
      status: zone.status,
      updated_by: extras.updatedBy ?? null,
      created_at: zone.createdAt.toISOString(),
      updated_at: zone.updatedAt.toISOString(),
    };

    if (extras.revisionCount !== undefined) {
      json.revision_count = extras.revisionCount;
    }
    if (extras.revisions !== undefined) {
      json.revisions = extras.revisions.map((revision) => {
        const user =
          revision.userId === null ? null : (extras.revisionUsers?.get(revision.userId) ?? null);
        return {
          id: revision.id,
          action: revision.action,
          before: revision.before,
          after: revision.after,
          user: user === null ? null : { id: user.id, name: user.name },
          created_at: revision.createdAt.toISOString(),
        };
      });
    }
    return json;
  }

  toDeliverySnapshot(delivery: Delivery): DeliverySnapshot {
    return {
      id: delivery.id,
      orderId: delivery.orderId,
      storeId: delivery.storeId,
      riderId: delivery.riderId,
      status: delivery.status as DeliverySnapshot['status'],
      distanceKm: delivery.distanceKm,
      deliveryFee: delivery.deliveryFee,
      riderCommission: delivery.riderCommission,
      assignedAt: toIso(delivery.assignedAt),
      deliveredAt: toIso(delivery.deliveredAt),
    };
  }

  toRiderProfileSnapshot(rider: Rider): RiderProfileSnapshot {
    return {
      id: rider.id,
      userId: rider.userId,
      vehicleType: rider.vehicleType,
      vehiclePlate: rider.vehiclePlate,
      isOnline: rider.isOnline,
      status: rider.status as RiderProfileSnapshot['status'],
      currentLatitude: rider.currentLatitude,
      currentLongitude: rider.currentLongitude,
    };
  }
}
