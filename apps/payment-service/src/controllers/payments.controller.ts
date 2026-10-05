import {
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Query,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import {
  Message,
  PaginatedResult,
  requestContext,
  resolvePagination,
} from '@taladelivery/common';
import { Payment } from '../entities/payment.entity';
import { PaymentService } from '../services/payment.service';
import { PaymentResourcesService } from '../services/payment-resources.service';

/**
 * Customer-facing payment endpoints (`/api/v1/payments`). The customer can
 * only ever see their own payments (orders never join other databases).
 */
@Controller('payments')
@UseGuards(AppKeyGuard, JwtAuthGuard)
export class PaymentsController {
  constructor(
    @InjectRepository(Payment) private readonly payments: Repository<Payment>,
    private readonly service: PaymentService,
    private readonly resources: PaymentResourcesService,
  ) {}

  @Get()
  @Message('Payments retrieved.')
  async index(
    @CurrentUser() user: JwtPayload,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const { items, total } = await this.service.forUser(user.sub, p, pp);
    return new PaginatedResult(
      items.map((payment) => this.resources.toJson(payment)),
      {
        currentPage: p,
        lastPage: Math.max(1, Math.ceil(total / pp)),
        perPage: pp,
        total,
        path: requestContext().path,
      },
    );
  }

  @Get(':id')
  @Message('Payment retrieved.')
  async show(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const payment = await this.service.byId(id);
    if (payment === null || payment.userId !== user.sub) {
      throw new NotFoundException('Payment not found.');
    }
    return this.resources.toJson(payment);
  }
}