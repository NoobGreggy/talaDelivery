import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { toMinor } from '@taladelivery/common';
import { DeliveryStatus, RiderStatus } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Delivery } from '../../entities/delivery.entity';
import { Rider } from '../../entities/rider.entity';
import { DeliveryZone } from '../../entities/delivery-zone.entity';
import { PricingService } from '../../services/pricing.service';
import { RiderCommissionService } from '../../services/rider-commission.service';
import { DeliveryService } from '../../services/delivery.service';
import { DispatchResourcesService } from '../../services/dispatch-resources.service';
import { CalculatePricingDto } from '../../dto/calculate-pricing.dto';
import { CreateRiderDto } from '../../dto/create-rider.dto';
import { CancelDeliveryInternalDto, CreateDeliveryDto } from '../../dto/delivery.dto';
import { RiderService } from '../../services/rider.service';

/**
 * Service-to-service endpoints for dispatch (mirrors the internal contract in
 * docs/internal-contracts.md §1.5). Only reachable with X-Service-Token.
 */
@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class DispatchInternalController {
  constructor(
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
    @InjectRepository(Rider) private readonly riders: Repository<Rider>,
    private readonly pricing: PricingService,
    private readonly commissions: RiderCommissionService,
    private readonly deliveryService: DeliveryService,
    private readonly riderService: RiderService,
    private readonly resources: DispatchResourcesService,
  ) {}

  @Post('pricing/calculate')
  async pricingCalculate(@Body() dto: CalculatePricingDto) {
    const breakdown = await this.pricing.calculate(
      dto.pickupLatitude ?? null,
      dto.pickupLongitude ?? null,
      dto.deliveryLatitude,
      dto.deliveryLongitude,
      dto.city ?? null,
      dto.province ?? null,
      dto.allowedZoneIds,
    );
    const commission = await this.commissions.calculate(
      toMinor(Number.parseFloat(breakdown.deliveryFee) || 0),
    );
    const zone = breakdown.zone;

    return {
      deliveryFee: breakdown.deliveryFee,
      distanceKm: breakdown.distanceKm,
      billableDistanceKm: breakdown.billableDistanceKm,
      distanceMethod: breakdown.distanceMethod,
      zone: {
        id: zone.id,
        name: zone.name,
        city: zone.city,
        province: zone.province,
        baseFee: zone.baseFee,
        includedKm: zone.includedKm,
        extraFeePerKm: zone.extraFeePerKm,
        maximumDeliveryKm: zone.maximumDeliveryKm,
        maximumDeliveryFee: zone.maximumDeliveryFee,
        distanceRoundingKm: zone.distanceRoundingKm,
        talaCoinsPercent: zone.talaCoinsPercent,
        status: zone.status,
      },
      riderCommission: commission.amount,
      commissionType: commission.type,
      commissionValue: commission.value,
    };
  }

  @Post('riders')
  async createRider(@Body() dto: CreateRiderDto) {
    const existing = await this.riders.findOne({ where: { userId: dto.userId } });
    if (existing !== null) {
      return this.resources.toRiderProfileSnapshot(existing);
    }

    const rider = await this.riders.save(
      this.riders.create({
        userId: dto.userId,
        vehicleType: dto.vehicleType,
        vehiclePlate: dto.vehiclePlate ?? null,
        licenseNumber: dto.licenseNumber ?? null,
        requirements: dto.requirements ?? null,
        isOnline: false,
        status: RiderStatus.Pending,
      }),
    );
    return this.resources.toRiderProfileSnapshot(rider);
  }

  @Get('riders/by-user/:userId')
  async riderByUser(@Param('userId', ParseIntPipe) userId: number) {
    const rider = await this.riderService.profileByUserId(userId);
    if (rider === null) {
      throw new NotFoundException('Rider profile not found.');
    }
    return this.resources.toRiderProfileSnapshot(rider);
  }

  @Post('deliveries')
  async createDelivery(@Body() dto: CreateDeliveryDto) {
    // Resolve the rate on the server and preserve it for the lifetime of the delivery.
    const zone = dto.deliveryZoneId == null ? null : await this.deliveries.manager
      .getRepository(DeliveryZone).findOneBy({ id: dto.deliveryZoneId });
    if (dto.deliveryZoneId != null && !zone) throw new NotFoundException('Delivery zone not found.');
    const delivery = await this.deliveries.save(
      this.deliveries.create({
        orderId: dto.orderId,
        deliveryZoneId: zone?.id ?? null,
        talaCoinsPercent: zone?.talaCoinsPercent ?? '0.00',
        storeId: dto.storeId,
        status: DeliveryStatus.Unassigned,
        pickupAddress: dto.pickupAddress ?? null,
        pickupLatitude: dto.pickupLatitude ?? null,
        pickupLongitude: dto.pickupLongitude ?? null,
        deliveryAddress: dto.deliveryAddress ?? null,
        deliveryLatitude: dto.deliveryLatitude ?? null,
        deliveryLongitude: dto.deliveryLongitude ?? null,
        distanceKm: dto.distanceKm ?? null,
        deliveryFee: dto.deliveryFee ?? null,
        riderCommission: dto.riderCommission ?? null,
        commissionType: dto.commissionType ?? null,
        commissionValue: dto.commissionValue ?? null,
      }),
    );
    return this.resources.toDeliverySnapshot(delivery);
  }

  @Get('deliveries/:id')
  async delivery(@Param('id', ParseIntPipe) id: number) {
    const delivery = await this.deliveries.findOne({ where: { id } });
    if (delivery === null) {
      throw new NotFoundException('Delivery not found.');
    }
    return this.resources.toDeliverySnapshot(delivery);
  }

  @Get('deliveries/:id/merchant')
  async merchantDelivery(@Param('id', ParseIntPipe) id: number) {
    const delivery = await this.deliveries.findOne({ where: { id } });
    if (!delivery) throw new NotFoundException('Delivery not found.');
    const rider = delivery.riderId == null ? null : await this.riders.findOne({ where: { id: delivery.riderId } });
    const resource = await this.resources.deliveryToJson(delivery, { rider });
    return { id: delivery.id, status: delivery.status, rider: resource.rider ? {
      id: resource.rider.id, name: resource.rider.name, phone: resource.rider.phone,
    } : null, distance: Number(delivery.distanceKm ?? 0), delivery_fee: Number(delivery.deliveryFee ?? 0),
      pickup_address: delivery.pickupAddress, delivery_address: delivery.deliveryAddress,
      created_at: delivery.createdAt.toISOString() };
  }

  @Get('deliveries/:id/tracking')
  async tracking(@Param('id', ParseIntPipe) id: number) {
    const delivery = await this.deliveries.findOneBy({ id });
    if (!delivery) throw new NotFoundException('Delivery not found.');
    const rider = delivery.riderId == null ? null : await this.riders.findOneBy({ id: delivery.riderId });
    const resource = await this.resources.deliveryToJson(delivery, { rider, skipHydration: true });
    return {
      id: resource.id, order_id: resource.order_id, status: resource.status,
      pickup_latitude: resource.pickup_latitude, pickup_longitude: resource.pickup_longitude,
      delivery_latitude: resource.delivery_latitude, delivery_longitude: resource.delivery_longitude,
      rider_location: resource.rider_location,
      rider: resource.rider ? { id: resource.rider.id, name: resource.rider.name, phone: resource.rider.phone } : null,
    };
  }

  @Post('deliveries/:id/cancel')
  async cancelDelivery(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CancelDeliveryInternalDto,
  ) {
    const delivery = await this.deliveries.findOne({ where: { id } });
    if (delivery === null) {
      throw new NotFoundException('Delivery not found.');
    }
    const updated = await this.deliveryService.cancel(
      delivery,
      dto.cancelledBy,
      dto.reason ?? null,
    );
    return this.resources.toDeliverySnapshot(updated);
  }

  @Get('admin/totals')
  async totals(
    @Query('ids') _ids?: string,
    @Query('ridersOnly') _ridersOnly?: string,
  ) {
    const [riders, deliveries, onlineRiders] = await Promise.all([
      this.riders.count(),
      this.deliveries.count(),
      this.riders.count({ where: { status: RiderStatus.Online } }),
    ]);
    return { riders, deliveries, onlineRiders };
  }
}
