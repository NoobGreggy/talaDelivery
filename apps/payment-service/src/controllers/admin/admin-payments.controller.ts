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
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  Roles,
  RolesGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import {
  Message,
  PaginatedResult,
  requestContext,
  resolvePagination,
} from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { PaymentService } from '../../services/payment.service';
import { PaymentResourcesService } from '../../services/payment-resources.service';
import { RefundPaymentDto } from '../../dto/refund.dto';

/**
 * Admin payment endpoints (`/api/v1/admin/payments`). Payments are the
 * authoritative payment state; only platform admins can refund.
 */
@Controller('admin/payments')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminPaymentsController {
  constructor(
    private readonly service: PaymentService,
    private readonly resources: PaymentResourcesService,
  ) {}

  @Get()
  @Message('Payments retrieved.')
  async index(
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const { items, total } = await this.service.all(p, pp);
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
  async show(@Param('id', ParseIntPipe) id: number) {
    const payment = await this.service.byId(id);
    if (payment === null) {
      throw new NotFoundException('Payment not found.');
    }
    return this.resources.toJson(payment);
  }

  @Post(':id/refund')
  @Message('Payment refunded.')
  async refund(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RefundPaymentDto,
  ) {
    const payment = await this.service.byId(id);
    if (payment === null) {
      throw new NotFoundException('Payment not found.');
    }
    const refunded = await this.service.refund(payment, dto.reason ?? null, user.sub);
    return this.resources.toJson(refunded);
  }
}