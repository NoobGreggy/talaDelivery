import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import {
  AppKeyGuard,
  JwtAuthGuard,
  Roles,
  RolesGuard,
} from '@taladelivery/auth';
import { Message, toMinor } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { DeliveryZone } from '../../entities/delivery-zone.entity';
import { PreviewZonePricingDto } from '../../dto/delivery-zone.dto';
import { PricingService } from '../../services/pricing.service';
import { RiderCommissionService } from '../../services/rider-commission.service';
import { ZoneBoundaryService } from '../../services/zone-boundary.service';

/**
 * Admin POST admin/delivery-zones/preview (mirrors Laravel
 * AdminDeliveryZonePricingPreviewController). Returns `covered: false` with a
 * reason instead of throwing when the pin is outside the boundary.
 *
 * NOTE: registered before AdminDeliveryZoneController so the static `preview`
 * segment resolves before the `:deliveryZone` route.
 */
@Controller('admin/delivery-zones/preview')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminDeliveryZonePricingPreviewController {
  constructor(
    private readonly pricing: PricingService,
    private readonly commissions: RiderCommissionService,
    private readonly boundaries: ZoneBoundaryService,
  ) {}

  @Post()
  @Message('Pricing preview completed.')
  async preview(@Body() dto: PreviewZonePricingDto) {
    const zone = new DeliveryZone();
    zone.boundaryGeoJson = (dto.zone.boundary_geojson ?? null) as DeliveryZone['boundaryGeoJson'];
    zone.baseFee = dto.zone.base_fee;
    zone.includedKm = dto.zone.included_km;
    zone.maximumDeliveryKm = dto.zone.maximum_delivery_km ?? null;
    zone.extraFeePerKm = dto.zone.extra_fee_per_km;
    zone.maximumDeliveryFee = dto.zone.maximum_delivery_fee ?? null;
    zone.distanceRoundingKm = dto.zone.distance_rounding_km;

    const deliveryLat = Number.parseFloat(dto.delivery_latitude);
    const deliveryLng = Number.parseFloat(dto.delivery_longitude);
    const pickupLat = Number.parseFloat(dto.pickup_latitude);
    const pickupLng = Number.parseFloat(dto.pickup_longitude);

    if (
      zone.boundaryGeoJson !== null &&
      !this.boundaries.covers(zone.boundaryGeoJson, deliveryLat, deliveryLng)
    ) {
      return {
        covered: false,
        reason: 'The delivery pin is outside this zone boundary.',
      };
    }

    try {
      const breakdown = await this.pricing.calculateForZone(
        zone,
        pickupLat,
        pickupLng,
        deliveryLat,
        deliveryLng,
        dto.distance_method ?? null,
      );
      const commission = await this.commissions.calculate(
        toMinor(Number.parseFloat(breakdown.deliveryFee) || 0),
      );
      return {
        covered: true,
        delivery_fee: breakdown.deliveryFee,
        distance_km: breakdown.distanceKm,
        billable_distance_km: breakdown.billableDistanceKm,
        distance_method: breakdown.distanceMethod,
        rider_commission: commission.amount,
      };
    } catch (error) {
      const reason =
        error instanceof Error ? error.message : 'Pricing could not be calculated.';
      return { covered: false, reason };
    }
  }
}