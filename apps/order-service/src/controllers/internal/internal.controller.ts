import {
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { Order } from '../../entities/order.entity';
import { OrderItem } from '../../entities/order-item.entity';
import { OrderService } from '../../services/order.service';

@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class OrderInternalController {
  constructor(private readonly orders: OrderService) {}

  @Get('orders/:id')
  async byId(@Param('id', ParseIntPipe) id: number) {
    const order = await this.orders.byId(id);
    if (!order) throw new NotFoundException('Order not found.');
    const items = await this.orders.itemsForOrder(order.id);
    return { ...this.toJson(order), items: items.map((item) => this.itemToJson(item)) };
  }

  @Get('orders/by-number/:orderNumber')
  async byOrderNumber(@Param('orderNumber') orderNumber: string) {
    const order = await this.orders.byOrderNumber(orderNumber);
    if (!order) throw new NotFoundException('Order not found.');
    const items = await this.orders.itemsForOrder(order.id);
    return { ...this.toJson(order), items: items.map((item) => this.itemToJson(item)) };
  }

  @Get('orders/by-delivery/:deliveryId')
  async byDeliveryId(@Param('deliveryId', ParseIntPipe) deliveryId: number) {
    const order = await this.orders.byDeliveryId(deliveryId);
    if (!order) throw new NotFoundException('Order not found.');
    const items = await this.orders.itemsForOrder(order.id);
    return { ...this.toJson(order), items: items.map((item) => this.itemToJson(item)) };
  }

  @Get('admin/totals')
  async totals() {
    return this.orders.adminTotals();
  }

  private toJson(order: Order) {
    return {
      id: order.id,
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
      storeSnapshot: order.storeSnapshot,
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
