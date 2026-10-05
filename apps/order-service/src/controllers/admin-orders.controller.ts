import { Controller, Get, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { AppKeyGuard, JwtAuthGuard, Roles, RolesGuard } from '@taladelivery/auth';
import { Message, PaginatedResult, requestContext, resolvePagination } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { OrderService } from '../services/order.service';
import { Order } from '../entities/order.entity';
import { AdminOrderFiltersDto } from '../dto/admin-order-filters.dto';

@Controller('admin/orders')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminOrdersController {
  constructor(private readonly orders: OrderService) {}

  @Get()
  @Message('Orders retrieved.')
  async index(@Query() filters: AdminOrderFiltersDto) {
    const { page, perPage } = resolvePagination({ page: filters.page, perPage: filters.per_page });
    const { items, total } = await this.orders.listForAdmin({ ...filters, page, perPage });
    return new PaginatedResult(items.map((order) => this.toJson(order)), {
      currentPage: page, lastPage: Math.max(1, Math.ceil(total / perPage)), perPage,
      total, path: requestContext().path,
    });
  }

  @Get(':id')
  @Message('Order retrieved.')
  async show(@Param('id', ParseIntPipe) id: number) {
    const order = await this.orders.require(id);
    const items = await this.orders.itemsForOrder(id);
    return { ...this.toJson(order), items: items.map((item) => ({
      id: item.id, product: { id: item.productId, name: item.productName },
      quantity: item.quantity, price: Number(item.unitPrice), subtotal: Number(item.subtotal),
    })) };
  }

  private toJson(order: Order) {
    return {
      id: order.id, order_number: order.orderNumber,
      customer: { id: order.customerId, name: order.customerName || `Customer #${order.customerId}`, phone: order.customerPhone },
      store: { id: order.storeId, name: order.storeName || `Store #${order.storeId}`, address: order.storeSnapshot?.address ?? order.pickupAddress },
      items: [], subtotal: Number(order.subtotal), discount: Number(order.discount),
      delivery_fee: Number(order.deliveryFee), total: Number(order.total),
      payment_method: order.paymentMethod, payment_status: order.paymentStatus,
      status: order.status, delivery_id: order.deliveryId, delivery_address: order.deliveryAddress,
      created_at: order.createdAt.toISOString(), updated_at: order.updatedAt.toISOString(),
      cancellation_reason: order.cancellationReason,
    };
  }
}
