import { Controller, Get, UseGuards } from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { RealtimeGateway } from '../realtime.gateway';

@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class RealtimeInternalController {
  constructor(private readonly realtime: RealtimeGateway) {}

  @Get('admin/totals')
  async totals() {
    return this.realtime.getStats();
  }
}
