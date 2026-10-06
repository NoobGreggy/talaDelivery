import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { DomainError, requestContext } from '@taladelivery/common';
import {
  ALL_TRACKABLE_DELIVERY_STATUSES,
  DeliveryOfferStatus,
  DeliveryStatus,
  OrderStatus,
  RiderStatus,
} from '@taladelivery/contracts';
import { EventType, EventPublisher, QueueName } from '@taladelivery/events';
import { Delivery } from '../entities/delivery.entity';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { Rider } from '../entities/rider.entity';
import { RiderLocationDto } from '../dto/rider-location.dto';
import { RiderMatchingService } from './rider-matching.service';
import { RemoteReferencesService } from './remote-references.service';
import { moneyString } from '../common/format.util';

export interface RiderStats {
  completed: number;
  earnings: string;
  acceptanceRate?: number | null;
  onTimeRate?: number | null;
}

export interface DeliveryPage {
  items: Delivery[];
  total: number;
}

/**
 * Rider profile / availability / location operations (mirrors Laravel
 * RiderController + Rider model relations). Deliveries are scoped to the
 * dispatch `riders.id`, not the identity user id.
 */
@Injectable()
export class RiderService {
  private readonly logger = new Logger(RiderService.name);

  constructor(
    @InjectRepository(Rider) private readonly riders: Repository<Rider>,
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
    @InjectRepository(DeliveryOffer) private readonly offers: Repository<DeliveryOffer>,
    private readonly matching: RiderMatchingService,
    private readonly refs: RemoteReferencesService,
    private readonly events: EventPublisher,
  ) {}

  async profileByUserId(userId: number): Promise<Rider | null> {
    return this.riders.findOne({ where: { userId } });
  }

  async findById(id: number): Promise<Rider | null> {
    return this.riders.findOne({ where: { id } });
  }

  /**
   * Rider POST /rider/online. Pending/rejected/suspended riders are rejected
   * with the Laravel-exact messages; these are business-rule failures and
   * surface as 422 `DomainError`, matching `goOffline` below.
   */
  async goOnline(rider: Rider): Promise<Rider> {
    if (rider.status === RiderStatus.Pending) {
      throw new DomainError('Your application is still pending admin approval.');
    }
    if (rider.status === RiderStatus.Rejected) {
      throw new DomainError('Your application was rejected by the admin.');
    }
    if (rider.status === RiderStatus.Suspended) {
      throw new DomainError('Suspended riders cannot go online.');
    }

    rider.isOnline = true;
    rider.status = RiderStatus.Online;
    await this.riders.update({ id: rider.id }, { isOnline: true, status: RiderStatus.Online });
    const updated = await this.riders.findOneByOrFail({ id: rider.id });

    if (updated.currentLatitude !== null && updated.currentLongitude !== null) {
      await this.retryUnmatchedDeliveries();
    }
    return updated;
  }

  /** Rider POST /rider/offline (422 when busy, Laravel-exact). */
  async goOffline(rider: Rider): Promise<Rider> {
    if (rider.status === RiderStatus.Busy) {
      throw new DomainError('You cannot go offline while delivering an order.');
    }
    rider.isOnline = false;
    rider.status = RiderStatus.Offline;
    await this.riders.update({ id: rider.id }, { isOnline: false, status: RiderStatus.Offline });
    return this.riders.findOneByOrFail({ id: rider.id });
  }

  /** Rider POST /rider/location — saves the location and re-broadcasts when active. */
  async updateLocation(rider: Rider, dto: RiderLocationDto): Promise<Rider> {
    const activeDelivery = await this.currentDelivery(rider);
    if (dto.delivery_id !== undefined && activeDelivery?.id !== dto.delivery_id) {
      throw new DomainError('This rider is not assigned to the selected delivery.');
    }

    const recordedAt = dto.recorded_at !== undefined ? new Date(dto.recorded_at) : new Date();
    const oldest = Date.now() - 2 * 60 * 1000;
    const newest = Date.now() + 30 * 1000;
    if (recordedAt.getTime() < oldest || recordedAt.getTime() > newest) {
      throw new DomainError('The rider location timestamp is stale or invalid.');
    }

    const hadLocation = rider.currentLatitude !== null && rider.currentLongitude !== null;
    rider.currentLatitude = String(dto.latitude);
    rider.currentLongitude = String(dto.longitude);
    rider.currentLocationAccuracy = dto.accuracy_m !== undefined ? String(dto.accuracy_m) : null;
    rider.currentLocationHeading = dto.heading_deg !== undefined ? String(dto.heading_deg) : null;
    rider.currentLocationSpeed = dto.speed_mps !== undefined ? String(dto.speed_mps) : null;
    rider.currentLocationUpdatedAt = recordedAt;
    // Location requests may hold a profile from before a simultaneous coin top-up.
    // Write only location fields so that stale profiles cannot overwrite the balance.
    await this.riders.update(
      { id: rider.id },
      {
        currentLatitude: rider.currentLatitude,
        currentLongitude: rider.currentLongitude,
        currentLocationAccuracy: rider.currentLocationAccuracy,
        currentLocationHeading: rider.currentLocationHeading,
        currentLocationSpeed: rider.currentLocationSpeed,
        currentLocationUpdatedAt: rider.currentLocationUpdatedAt,
      },
    );
    const updated = await this.riders.findOneByOrFail({ id: rider.id });

    if (activeDelivery !== null) {
      await this.events.publishEvent(
        QueueName.LocationEvents,
        EventType.RiderLocationUpdated,
        {
          deliveryId: activeDelivery.id,
          orderId: activeDelivery.orderId,
          riderId: rider.id,
          latitude: String(dto.latitude),
          longitude: String(dto.longitude),
          accuracyM: dto.accuracy_m ?? null,
          headingDeg: dto.heading_deg ?? null,
          speedMps: dto.speed_mps ?? null,
          recordedAt: recordedAt.toISOString(),
        },
        requestContext().correlationId,
      );
    }

    if (!hadLocation && updated.status === RiderStatus.Online) {
      await this.retryUnmatchedDeliveries();
    }
    return updated;
  }

  /** The rider's active delivery (ASSIGNED | ACCEPTED | PICKED_UP | IN_TRANSIT). */
  async currentDelivery(rider: Rider): Promise<Delivery | null> {
    const delivery = await this.deliveries.findOne({
      where: { riderId: rider.id },
      order: { id: 'DESC' },
    });
    return delivery !== null &&
      ALL_TRACKABLE_DELIVERY_STATUSES.includes(delivery.status as DeliveryStatus)
      ? delivery
      : null;
  }

  /** Rider POST /rider/location uses this to resolve the assigned delivery param. */
  async deliveryForRider(rider: Rider, deliveryId: number): Promise<Delivery | null> {
    const delivery = await this.deliveries.findOne({ where: { id: deliveryId } });
    return delivery !== null && delivery.riderId === rider.id ? delivery : null;
  }

  /** Rider GET /rider/deliveries (paginated, optional status filter). */
  async deliveriesOf(
    riderId: number,
    status: string | undefined,
    page: number,
    perPage: number,
  ): Promise<DeliveryPage> {
    const [items, total] = await this.deliveries.findAndCount({
      where: status ? { riderId, status } : { riderId },
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { items, total };
  }

  /** Admin GET /admin/deliveries (paginated). */
  async adminDeliveries(
    status: string | undefined,
    page: number,
    perPage: number,
  ): Promise<DeliveryPage> {
    const [items, total] = await this.deliveries.findAndCount({
      where: status ? { status } : {},
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { items, total };
  }

  /** Completed-delivery count + total rider_commission for a rider. */
  async stats(riderId: number): Promise<RiderStats> {
    const rows = await this.deliveries
      .createQueryBuilder('delivery')
      .select('delivery.rider_commission', 'commission')
      .where('delivery.rider_id = :riderId', { riderId })
      .andWhere('delivery.status = :status', { status: DeliveryStatus.Delivered })
      .getRawMany();

    const completed = rows.length;
    const totalMinor = rows.reduce((sum, row) => {
      const value = Number.parseFloat(String(row.commission ?? '0')) || 0;
      return sum + Math.round(value * 100);
    }, 0);

    const counts = await this.offers
      .createQueryBuilder('offer')
      .select('COUNT(*) FILTER (WHERE offer.status = :accepted)', 'accepted')
      .addSelect('COUNT(*)', 'answered')
      .where('offer.rider_id = :riderId', { riderId })
      .andWhere('offer.status IN (:...statuses)', {
        statuses: [DeliveryOfferStatus.Accepted, DeliveryOfferStatus.Rejected],
      })
      .setParameter('accepted', DeliveryOfferStatus.Accepted)
      .getRawOne<{ accepted: string; answered: string }>();
    const answered = Number(counts?.answered ?? 0);
    const accepted = Number(counts?.accepted ?? 0);
    return {
      completed,
      earnings: moneyString(totalMinor / 100),
      acceptanceRate: answered === 0 ? null : Math.round((accepted * 10000) / answered) / 100,
      // A delivery deadline is not currently recorded; do not manufacture a rate.
      onTimeRate: null,
    };
  }

  /**
   * Retry matching for every UNASSIGNED delivery whose order is
   * READY_FOR_PICKUP and that has no pending offer (mirrors
   * RiderController::retryUnmatchedDeliveries). Runs after a rider comes
   * online or supplies their first location.
   */
  async retryUnmatchedDeliveries(): Promise<void> {
    const candidates = await this.deliveries.find({
      where: { status: DeliveryStatus.Unassigned, riderId: IsNull() },
      order: { id: 'ASC' },
    });

    for (const delivery of candidates) {
      const hasPendingOffer = await this.offers.exists({
        where: { deliveryId: delivery.id, status: DeliveryOfferStatus.Pending },
      });
      if (hasPendingOffer) {
        continue;
      }

      const order = await this.refs.orderById(delivery.orderId);
      if (order === null || order.status !== OrderStatus.ReadyForPickup) {
        continue;
      }
      try {
        await this.matching.matchNext(delivery);
      } catch (error) {
        this.logger.warn(`Retry match failed for delivery #${delivery.id}`, error as Error);
      }
    }
  }
}
