import { Body, Controller, Get, Headers, NotFoundException, Param, ParseIntPipe, Post, Query, UseGuards } from '@nestjs/common';
import { AppKeyGuard, CurrentUser, JwtAuthGuard, Roles, RolesGuard, JwtPayload } from '@taladelivery/auth';
import { Message, PaginatedResult, requestContext, resolvePagination, ServiceClientFactory } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { OrderService } from '../services/order.service';
import { AdminOrderFiltersDto } from '../dto/admin-order-filters.dto';
import { Order } from '../entities/order.entity';

class CancelStoreOrderDto {
  @IsOptional() @IsString() @MaxLength(500) reason?: string;
}

@Controller(['store/orders', 'merchant/orders'])
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.StoreAdmin)
export class StoreOrdersController {
  constructor(private readonly orders: OrderService, private readonly factory: ServiceClientFactory) {}

  async resolveStore(userId: number, selected?: string): Promise<number> {
    const stores = await this.factory.create('MERCHANT_SERVICE_URL').get<Array<{ id: number }>>(`/internal/stores/by-user/${userId}`);
    const store = selected ? stores.find((store) => String(store.id) === selected) : stores[0];
    if (!store) throw new NotFoundException('Store membership not found.');
    return store.id;
  }

  @Get() @Message('Store orders retrieved.')
  async list(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Query() filters: AdminOrderFiltersDto) {
    const store = await this.resolveStore(user.sub, selected);
    const { page, perPage } = resolvePagination({ page: filters.page, perPage: filters.per_page });
    const { items, total } = await this.orders.listForAdmin({ page, perPage, store, status: filters.status, search: filters.search });
    return new PaginatedResult(items.map((order) => this.resource(order)), {
      currentPage: page, lastPage: Math.max(1, Math.ceil(total / perPage)), perPage, total, path: requestContext().path,
    });
  }

  @Get(':id') @Message('Store order retrieved.')
  async show(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    return this.detail(await this.ownedOrder(user.sub, selected, id));
  }

  @Post(':id/confirm') @Message('Order confirmed.')
  async confirm(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    return this.detail(await this.orders.confirm(await this.ownedOrder(user.sub, selected, id)));
  }
  @Post(':id/preparing') @Message('Order is being prepared.')
  async preparing(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    return this.detail(await this.orders.markPreparing(await this.ownedOrder(user.sub, selected, id)));
  }
  @Post(':id/ready') @Message('Order is ready for pickup.')
  async ready(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    return this.detail(await this.orders.markReadyForPickup(await this.ownedOrder(user.sub, selected, id)));
  }
  @Post(':id/cancel') @Message('Order cancelled.')
  async cancel(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number, @Body() dto: CancelStoreOrderDto) {
    return this.detail(await this.orders.cancel(await this.ownedOrder(user.sub, selected, id), 'merchant', dto.reason));
  }

  private async ownedOrder(userId: number, selected: string, id: number) {
    const store = await this.resolveStore(userId, selected);
    const order = await this.orders.require(id);
    if (order.storeId !== store) throw new NotFoundException('Order not found.');
    return order;
  }

  private async detail(order: Order) {
    const items = await this.orders.itemsForOrder(order.id);
    const delivery = order.deliveryId == null ? null : await this.factory.create('DISPATCH_SERVICE_URL')
      .get(`/internal/deliveries/${order.deliveryId}/merchant`);
    return { ...this.resource(order), delivery, items: items.map((item) => ({
      id: item.id, product: { id: item.productId, name: item.productName }, quantity: item.quantity,
      price: Number(item.unitPrice), subtotal: Number(item.subtotal),
    })) };
  }

  private resource(order: Order) {
    return { id: order.id, order_number: order.orderNumber, store: { id: order.storeId, name: order.storeName },
      customer: { id: order.customerId, name: order.customerName || `Customer #${order.customerId}`, phone: order.customerPhone },
      items: [], subtotal: Number(order.subtotal), delivery_fee: Number(order.deliveryFee), total: Number(order.total),
      status: order.status, payment_method: order.paymentMethod, payment_status: order.paymentStatus,
      delivery_id: order.deliveryId, delivery_address: order.deliveryAddress, created_at: order.createdAt.toISOString(),
      updated_at: order.updatedAt.toISOString(), cancellation_reason: order.cancellationReason };
  }
}
