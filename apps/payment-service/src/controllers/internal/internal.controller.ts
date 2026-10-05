import {
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { PaymentService } from '../../services/payment.service';
import { PaymentResourcesService } from '../../services/payment-resources.service';

/**
 * Service-to-service payment endpoints (docs/internal-contracts.md §1.6):
 * only reachable with X-Service-Token. Used by order (projection) and future
 * webhook flows.
 */
@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class PaymentInternalController {
  constructor(
    private readonly service: PaymentService,
    private readonly resources: PaymentResourcesService,
  ) {}

  @Get('payments/:id')
  async payment(@Param('id', ParseIntPipe) id: number) {
    const payment = await this.service.byId(id);
    if (payment === null) {
      throw new NotFoundException('Payment not found.');
    }
    return this.resources.toSnapshot(payment);
  }

  @Get('payments/by-order/:orderId')
  async paymentByOrder(@Param('orderId', ParseIntPipe) orderId: number) {
    const payment = await this.service.byOrder(orderId);
    return payment === null ? null : this.resources.toSnapshot(payment);
  }

  @Post('payments/:id/capture')
  async capture(@Param('id', ParseIntPipe) id: number) {
    const payment = await this.service.byId(id);
    if (payment === null) {
      throw new NotFoundException('Payment not found.');
    }
    return this.resources.toSnapshot(await this.service.capture(payment, 'internal'));
  }

  @Post('payments/:id/fail')
  async fail(@Param('id', ParseIntPipe) id: number) {
    const payment = await this.service.byId(id);
    if (payment === null) {
      throw new NotFoundException('Payment not found.');
    }
    return this.resources.toSnapshot(await this.service.fail(payment, 'webhook'));
  }

  @Get('admin/totals')
  async totals() {
    return this.service.adminTotals();
  }
}