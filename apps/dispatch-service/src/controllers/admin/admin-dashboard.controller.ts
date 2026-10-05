import { Controller, Get, Logger, UseGuards } from '@nestjs/common';
import {
  AppKeyGuard,
  JwtAuthGuard,
  Roles,
  RolesGuard,
} from '@taladelivery/auth';
import { Message, type ServiceClient, ServiceClientFactory } from '@taladelivery/common';
import { Role, RiderStatus } from '@taladelivery/contracts';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Delivery } from '../../entities/delivery.entity';
import { Rider } from '../../entities/rider.entity';

interface OrderTotals {
  orders: number;
  pendingOrders: number;
  todayOrders: number;
  todayDelivered: number;
  todayRevenue: string;
}

const EMPTY_ORDER_TOTALS: OrderTotals = {
  orders: 0,
  pendingOrders: 0,
  todayOrders: 0,
  todayDelivered: 0,
  todayRevenue: '0.00',
};

/**
 * Admin dashboard aggregation (mirrors Laravel DashboardController). Dispatch
 * owns riders/deliveries; store/customer/order counters come from the owning
 * services' internal `/internal/admin/totals` endpoints.
 */
@Controller('admin/dashboard')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminDashboardController {
  private readonly logger = new Logger(AdminDashboardController.name);
  private readonly identity: ServiceClient;
  private readonly merchant: ServiceClient;
  private readonly order: ServiceClient;

  constructor(
    factory: ServiceClientFactory,
    @InjectRepository(Rider) private readonly riders: Repository<Rider>,
    @InjectRepository(Delivery) private readonly deliveries: Repository<Delivery>,
  ) {
    this.identity = factory.create('IDENTITY_SERVICE_URL');
    this.merchant = factory.create('MERCHANT_SERVICE_URL');
    this.order = factory.create('ORDER_SERVICE_URL');
  }

  @Get()
  @Message('Dashboard retrieved.')
  async index() {
    const orderTotals = await this.orderTotals();
    const [stores, customers, riders, deliveries, onlineRiders] = await Promise.all([
      this.merchantTotal(),
      this.identityTotal(),
      this.riders.count(),
      this.deliveries.count(),
      this.riders.count({ where: { status: RiderStatus.Online } }),
    ]);

    return {
      totals: {
        stores,
        riders,
        customers,
        orders: orderTotals.orders,
        deliveries,
        pending_orders: orderTotals.pendingOrders,
        online_riders: onlineRiders,
      },
      today: {
        orders: orderTotals.todayOrders,
        delivered: orderTotals.todayDelivered,
        revenue: orderTotals.todayRevenue,
      },
    };
  }

  private async orderTotals(): Promise<OrderTotals> {
    try {
      const totals = await this.order.get<OrderTotals>('/internal/admin/totals');
      return totals ?? EMPTY_ORDER_TOTALS;
    } catch (err) {
      // Degrade to zeroes so one unavailable service cannot 500 the whole
      // dashboard, but never swallow it silently — a broken aggregate here
      // otherwise looks identical to a genuinely empty platform.
      this.logger.warn(`order totals unavailable: ${(err as Error).message}`);
      return EMPTY_ORDER_TOTALS;
    }
  }

  private async merchantTotal(): Promise<number> {
    try {
      const totals = await this.merchant.get<{ stores: number }>('/internal/admin/totals');
      return totals?.stores ?? 0;
    } catch (err) {
      this.logger.warn(`store totals unavailable: ${(err as Error).message}`);
      return 0;
    }
  }

  private async identityTotal(): Promise<number> {
    try {
      const totals = await this.identity.get<{ customers: number }>('/internal/admin/totals');
      return totals?.customers ?? 0;
    } catch (err) {
      this.logger.warn(`customer totals unavailable: ${(err as Error).message}`);
      return 0;
    }
  }
}