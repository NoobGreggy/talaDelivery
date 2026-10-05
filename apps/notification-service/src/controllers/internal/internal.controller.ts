import { Controller, Get, UseGuards } from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { NotificationService } from '../../services/notification.service';

@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class NotificationInternalController {
  constructor(private readonly notifications: NotificationService) {}

  @Get('notifications/health')
  async health() {
    return this.notifications.health();
  }
}
