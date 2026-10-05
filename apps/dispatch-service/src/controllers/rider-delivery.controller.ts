import {
  Controller,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import { Message } from '@taladelivery/common';
import { DeliveryService } from '../services/delivery.service';
import { RiderService } from '../services/rider.service';
import { DispatchResourcesService } from '../services/dispatch-resources.service';

/**
 * Rider delivery transitions (mirrors Laravel RiderDeliveryController).
 * The assigned rider advances the delivery state machine; order-status side
 * effects flow to order-service through delivery.* events.
 */
@Controller('rider/deliveries')
@UseGuards(AppKeyGuard, JwtAuthGuard)
export class RiderDeliveryController {
  constructor(
    private readonly deliveries: DeliveryService,
    private readonly riders: RiderService,
    private readonly resources: DispatchResourcesService,
  ) {}

  @Post(':delivery/arrived')
  @Message('Arrival recorded.')
  async arrived(
    @CurrentUser() user: JwtPayload,
    @Param('delivery', ParseIntPipe) deliveryId: number,
  ) {
    const { delivery, rider } = await this.load(user, deliveryId);
    const updated = await this.deliveries.arrived(delivery, rider);
    return this.resources.deliveryToJson(updated, { rider });
  }

  @Post(':delivery/pickup')
  @Message('Order picked up.')
  async pickup(
    @CurrentUser() user: JwtPayload,
    @Param('delivery', ParseIntPipe) deliveryId: number,
  ) {
    const { delivery, rider } = await this.load(user, deliveryId);
    const updated = await this.deliveries.pickup(delivery, rider);
    return this.resources.deliveryToJson(updated, { rider });
  }

  @Post(':delivery/start')
  @Message('Delivery started.')
  async start(
    @CurrentUser() user: JwtPayload,
    @Param('delivery', ParseIntPipe) deliveryId: number,
  ) {
    const { delivery, rider } = await this.load(user, deliveryId);
    const updated = await this.deliveries.start(delivery, rider);
    return this.resources.deliveryToJson(updated, { rider });
  }

  @Post(':delivery/complete')
  @Message('Delivery completed.')
  async complete(
    @CurrentUser() user: JwtPayload,
    @Param('delivery', ParseIntPipe) deliveryId: number,
  ) {
    const { delivery, rider } = await this.load(user, deliveryId);
    const updated = await this.deliveries.complete(delivery, rider);
    return this.resources.deliveryToJson(updated, { rider });
  }

  private async load(user: JwtPayload, deliveryId: number) {
    const rider = await this.riders.profileByUserId(user.sub);
    if (rider === null) {
      throw new NotFoundException('Rider profile not found.');
    }
    const delivery = await this.riders.deliveryForRider(rider, deliveryId);
    if (delivery === null) {
      throw new NotFoundException('This delivery is no longer available.');
    }
    return { delivery, rider };
  }
}