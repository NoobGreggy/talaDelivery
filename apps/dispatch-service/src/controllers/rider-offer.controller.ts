import {
  Controller,
  Get,
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
import { DeliveryOfferStatus } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThan, Repository } from 'typeorm';
import { DeliveryOffer } from '../entities/delivery-offer.entity';
import { RiderMatchingService } from '../services/rider-matching.service';
import { RiderService } from '../services/rider.service';
import { DispatchResourcesService } from '../services/dispatch-resources.service';

/**
 * Rider offers (mirrors Laravel RiderOfferController): pending offers for the
 * authenticated rider, accept (atomic, concurrency-safe) and reject.
 */
@Controller('rider/offers')
@UseGuards(AppKeyGuard, JwtAuthGuard)
export class RiderOfferController {
  constructor(
    @InjectRepository(DeliveryOffer) private readonly offers: Repository<DeliveryOffer>,
    private readonly matching: RiderMatchingService,
    private readonly riders: RiderService,
    private readonly resources: DispatchResourcesService,
  ) {}

  @Get()
  @Message('Offers retrieved.')
  async index(@CurrentUser() user: JwtPayload) {
    const rider = await this.requireRider(user);
    const offers = await this.offers.find({
      where: {
        riderId: rider.id,
        status: DeliveryOfferStatus.Pending,
        expiresAt: MoreThan(new Date()),
      },
      order: { id: 'DESC' },
    });

    return Promise.all(
      offers.map((offer) => this.resources.offerToJson(offer)),
    );
  }

  @Post(':offer/accept')
  @Message('Offer accepted.')
  async accept(@CurrentUser() user: JwtPayload, @Param('offer', ParseIntPipe) offerId: number) {
    const rider = await this.requireRider(user);
    const offer = await this.findOffer(offerId);
    const delivery = await this.matching.accept(offer, rider);
    const deliveryJson = await this.resources.deliveryToJson(delivery, { rider });
    const accepted = await this.findOffer(offerId);
    return this.resources.offerToJson(accepted, { deliveryJson, skipHydration: true });
  }

  @Post(':offer/reject')
  @Message('Offer rejected.')
  async reject(@CurrentUser() user: JwtPayload, @Param('offer', ParseIntPipe) offerId: number) {
    const rider = await this.requireRider(user);
    const offer = await this.findOffer(offerId);
    const updated = await this.matching.reject(offer, rider);
    return this.resources.offerToJson(updated, { skipHydration: true });
  }

  private async findOffer(offerId: number): Promise<DeliveryOffer> {
    const offer = await this.offers.findOne({ where: { id: offerId } });
    if (offer === null) {
      throw new NotFoundException('This offer is no longer available.');
    }
    return offer;
  }

  private async requireRider(user: JwtPayload) {
    const rider = await this.riders.profileByUserId(user.sub);
    if (rider === null) {
      throw new NotFoundException('Rider profile not found.');
    }
    return rider;
  }
}
