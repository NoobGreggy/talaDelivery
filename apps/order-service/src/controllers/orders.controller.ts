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
import { Message, PaginatedResult, requestContext, resolvePagination } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { CreateOrderDto } from '../dto/create-order.dto';
import { DeliveryQuoteDto } from '../dto/delivery-quote.dto';
import { Order } from '../entities/order.entity';
import { OrderItem } from '../entities/order-item.entity';
import { OrderService } from '../services/order.service';

@Controller()
@UseGuards(AppKeyGuard)
export class OrdersController {
  constructor(private readonly orders: OrderService) {}

  @Post('orders/delivery-quote')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.Customer)
  @Message('Delivery fee calculated.')
  quoteDelivery(@Body() dto: DeliveryQuoteDto) { return this.orders.quoteDelivery(dto); }

  @Get('orders')
  @UseGuards(JwtAuthGuard)
  @Message('Orders retrieved.')
  async index(
    @CurrentUser() user: JwtPayload,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const { items, total } = await this.orders.listByCustomer(user.sub, p, pp);
    return new PaginatedResult(
      items.map((order) => this.toJson(order)),
      {
        currentPage: p,
        lastPage: Math.max(1, Math.ceil(total / pp)),
        perPage: pp,
        total,
        path: requestContext().path,
      },
    );
  }

  @Get('orders/:id')
  @UseGuards(JwtAuthGuard)
  @Message('Order retrieved.')
  async show(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const order = await this.orders.require(id);
    if (order.customerId !== user.sub) throw new NotFoundException('Order not found.');
    const items = await this.orders.itemsForOrder(order.id);
    const delivery = await this.orders.deliveryTracking(order);
    return { ...this.toJson(order), delivery, items: items.map((item) => this.itemToJson(item)) };
  }

  @Post('orders')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.Customer)
  @Message('Order created.')
  async create(@CurrentUser() user: JwtPayload, @Body() dto: CreateOrderDto) {
    const order = await this.orders.create(user.sub, dto);
    const items = await this.orders.itemsForOrder(order.id);
    return { ...this.toJson(order), items: items.map((item) => this.itemToJson(item)) };
  }

  @Post('orders/:id/cancel')
  @UseGuards(JwtAuthGuard)
  @Message('Order cancelled.')
  async cancel(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number, @Body('reason') reason?: string) {
    const order = await this.orders.require(id);
    if (order.customerId !== user.sub) throw new NotFoundException('Order not found.');
    const cancelled = await this.orders.cancel(order, 'customer', reason);
    return this.toJson(cancelled);
  }

  @Post('orders/:id/confirm')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.StoreAdmin)
  @Message('Order confirmed.')
  async confirm(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const order = await this.orders.requireForMerchant(id, user.sub);
    const confirmed = await this.orders.confirm(order);
    return this.toJson(confirmed);
  }

  @Post('orders/:id/preparing')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.StoreAdmin)
  @Message('Order is being prepared.')
  async markPreparing(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const order = await this.orders.requireForMerchant(id, user.sub);
    const updated = await this.orders.markPreparing(order);
    return this.toJson(updated);
  }

  @Post('orders/:id/ready')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.StoreAdmin)
  @Message('Order is ready for pickup.')
  async markReady(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const order = await this.orders.requireForMerchant(id, user.sub);
    const updated = await this.orders.markReadyForPickup(order);
    return this.toJson(updated);
  }

  private toJson(order: Order) {
    return {
      id: order.id,
      notes: order.notes,
      orderNumber: order.orderNumber,
      customerId: order.customerId,
      storeId: order.storeId,
      deliveryId: order.deliveryId,
      status: order.status,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      subtotal: order.subtotal,
      discount: order.discount,
      deliveryFee: order.deliveryFee,
      total: order.total,
      pickupAddress: order.pickupAddress,
      pickupLatitude: order.pickupLatitude,
      pickupLongitude: order.pickupLongitude,
      deliveryAddress: order.deliveryAddress,
      deliveryLatitude: order.deliveryLatitude,
      deliveryLongitude: order.deliveryLongitude,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      storeName: order.storeName,
      cancelledBy: order.cancelledBy,
      cancellationReason: order.cancellationReason,
      cancelledAt: order.cancelledAt,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
    };
  }

  private itemToJson(item: OrderItem) {
    return {
      id: item.id,
      orderId: item.orderId,
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      subtotal: item.subtotal,
    };
  }
}
