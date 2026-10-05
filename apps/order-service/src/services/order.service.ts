import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { InjectDataSource } from '@nestjs/typeorm';
import { Between, DataSource, Repository } from 'typeorm';
import {
  DomainError,
  requestContext,
  ServiceCallError,
  ServiceClient,
  ServiceClientFactory,
  toMinor,
  fromMinor,
} from '@taladelivery/common';
import {
  ORDER_TRANSITIONS,
  OrderStatus,
  PaymentMethod,
  PaymentStatus,
  ErrorCode,
} from '@taladelivery/contracts';
import { EventType, EventPublisher, QueueName, IdempotencyKeyPrefix } from '@taladelivery/events';
import { CreateOrderDto } from '../dto/create-order.dto';
import { DeliveryQuoteDto } from '../dto/delivery-quote.dto';
import { Order } from '../entities/order.entity';
import { OrderItem } from '../entities/order-item.entity';
import { Redis } from 'ioredis';

interface DeliveryPricing {
  deliveryFee: string;
  distanceKm: string;
  billableDistanceKm: string;
  distanceMethod: string;
  riderCommission: string;
  commissionType: string;
  commissionValue: string;
  zone: { id: number; name: string };
}

@Injectable()
export class OrderService {
  private readonly logger = new Logger(OrderService.name);
  private readonly redis: Redis;

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    @InjectRepository(Order) private readonly orders: Repository<Order>,
    @InjectRepository(OrderItem) private readonly orderItems: Repository<OrderItem>,
    private readonly events: EventPublisher,
    private readonly factory: ServiceClientFactory,
  ) {
    this.redis = new Redis({
      host: process.env.REDIS_HOST ?? 'localhost',
      port: Number.parseInt(process.env.REDIS_PORT ?? '6379', 10),
    });
  }

  private get merchant(): ServiceClient {
    return this.factory.create('MERCHANT_SERVICE_URL');
  }

  private get catalog(): ServiceClient {
    return this.factory.create('CATALOG_SERVICE_URL');
  }

  private get dispatch(): ServiceClient {
    return this.factory.create('DISPATCH_SERVICE_URL');
  }

  private get payment(): ServiceClient {
    return this.factory.create('PAYMENT_SERVICE_URL');
  }

  async deliveryTracking(order: Order): Promise<Record<string, unknown> | null> {
    if (order.deliveryId === null) return null;
    const tracking = await this.dispatch.get<Record<string, unknown>>(
      `/internal/deliveries/${order.deliveryId}/tracking`);
    if (tracking.order_id !== order.id) throw new NotFoundException('Delivery not found.');
    return tracking;
  }

  /**
   * Translate an upstream (cross-service) 4xx into a customer-facing business
   * failure.
   *
   * Without this, `ServiceClientError`s from catalog/dispatch/merchant escape
   * uncaught and the exception filter reports 500 — so "insufficient stock",
   * "store is closed" or "address is outside the delivery zone" look like
   * server faults. Genuine 5xx and transport failures keep bubbling as 500.
   */
  private async upstream<T>(work: Promise<T>): Promise<T> {
    try {
      return await work;
    } catch (err) {
      if (err instanceof ServiceCallError && err.status >= 400 && err.status < 500) {
        throw new DomainError(err.message, { cause: err });
      }
      throw err;
    }
  }

  private async deliveryPricing(
    store: { latitude?: string | null; longitude?: string | null; deliveryZoneIds?: number[] },
    dto: DeliveryQuoteDto | CreateOrderDto,
  ): Promise<DeliveryPricing> {
    if (!store.deliveryZoneIds?.length) throw new DomainError('This store has no assigned delivery zones. Please choose another store.');
    return this.upstream(this.dispatch.post<DeliveryPricing>('/internal/pricing/calculate', {
      pickupLatitude: store.latitude ?? null,
      pickupLongitude: store.longitude ?? null,
      deliveryLatitude: dto.deliveryLatitude,
      deliveryLongitude: dto.deliveryLongitude,
      city: dto.city ?? null,
      province: dto.province ?? null,
      allowedZoneIds: store.deliveryZoneIds,
    }));
  }

  async quoteDelivery(dto: DeliveryQuoteDto) {
    const store = await this.upstream(this.merchant.get<{ status: string; latitude?: string; longitude?: string; deliveryZoneIds?: number[] }>(
      `/internal/stores/${dto.storeId}`,
    ));
    if (!store || store.status !== 'ACTIVE') throw new DomainError('This store is not accepting orders right now.');
    const pricing = await this.deliveryPricing(store, dto);
    // Quotes only calculate; they never reserve stock, create orders or emit events.
    return { deliveryFee: pricing.deliveryFee, distanceKm: pricing.distanceKm,
      billableDistanceKm: pricing.billableDistanceKm, distanceMethod: pricing.distanceMethod,
      zone: { id: pricing.zone.id, name: pricing.zone.name } };
  }

  async create(customerId: number, dto: CreateOrderDto): Promise<Order> {
    const idempotencyKey = await this.checkIdempotency(customerId, dto);

    const store = await this.upstream(
      this.merchant.get<{ id: number; status: string; name?: string; address?: string; latitude?: string; longitude?: string; deliveryZoneIds?: number[] }>(
        `/internal/stores/${dto.storeId}`,
      ),
    );
    if (!store || store.status !== 'ACTIVE') {
      throw new DomainError('This store is not accepting orders right now.');
    }

    const validation = await this.upstream(
      this.catalog.post<{
        items: Array<{ productId: number; name: string; quantity: number; unitPrice: string; subtotal: string }>;
        subtotal: string;
      }>('/internal/orders/validate', {
        storeId: dto.storeId,
        items: dto.items,
      }),
    );

    const pricing = await this.deliveryPricing(store, dto);

    const subtotalMinor = toMinor(validation.subtotal);
    const deliveryFeeMinor = toMinor(pricing.deliveryFee);
    const totalMinor = subtotalMinor + deliveryFeeMinor;
    const total = fromMinor(totalMinor);

    const orderNumber = this.generateOrderNumber();

    const order = await this.dataSource.transaction(async (manager) => {
      const orderRepo = manager.getRepository(Order);
      const itemRepo = manager.getRepository(OrderItem);

      const saved = await orderRepo.save(
        orderRepo.create({
          orderNumber,
          customerId,
          storeId: dto.storeId,
          notes: dto.notes?.trim() || null,
          deliveryId: null,
          status: OrderStatus.Pending,
          paymentMethod: PaymentMethod.Cod,
          paymentStatus: PaymentStatus.Pending,
          subtotal: validation.subtotal,
          discount: '0.00',
          deliveryFee: pricing.deliveryFee,
          total,
          pickupAddress: store.address ?? null,
          pickupLatitude: store.latitude ?? null,
          pickupLongitude: store.longitude ?? null,
          deliveryAddress: dto.deliveryAddress,
          deliveryLatitude: dto.deliveryLatitude,
          deliveryLongitude: dto.deliveryLongitude,
          customerName: dto.customerName ?? '',
          customerPhone: dto.customerPhone ?? null,
          storeName: store.name ?? '',
          storeSnapshot: store,
          cancelledBy: null,
          cancellationReason: null,
          cancelledAt: null,
        }),
      );

      for (const item of validation.items) {
        await itemRepo.save(
          itemRepo.create({
            orderId: saved.id,
            productId: item.productId,
            productName: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            subtotal: item.subtotal,
          }),
        );
      }

      return saved;
    });

    const delivery = await this.upstream(
      this.dispatch.post<{
        id: number;
      }>('/internal/deliveries', {
        orderId: order.id,
        storeId: dto.storeId,
        pickupAddress: store.address ?? null,
        pickupLatitude: store.latitude ?? null,
        pickupLongitude: store.longitude ?? null,
        deliveryAddress: dto.deliveryAddress,
        deliveryLatitude: dto.deliveryLatitude,
        deliveryLongitude: dto.deliveryLongitude,
        distanceKm: pricing.distanceKm,
        deliveryFee: pricing.deliveryFee,
        riderCommission: pricing.riderCommission,
        commissionType: pricing.commissionType,
        commissionValue: pricing.commissionValue,
        deliveryZoneId: pricing.zone?.id,
      }),
    );

    order.deliveryId = delivery.id;
    await this.orders.save(order);

    await this.payment.get(`/internal/payments/by-order/${order.id}`).catch(() => null);

    const orderCreated = {
      orderId: order.id,
      orderNumber: order.orderNumber,
      customerId: order.customerId,
      storeId: order.storeId,
      deliveryId: order.deliveryId,
      status: order.status,
      total: order.total,
    };

    // `create` bypasses publishStatus, so each audience is published to
    // explicitly. Nothing goes to `order-events`: dispatch only acts on
    // `ready_for_pickup` and `cancelled`, and would discard the rest.
    //
    // payment-service provisions the COD record from order.created.
    await this.events.publishEvent(
      QueueName.PaymentJobs,
      EventType.OrderCreated,
      orderCreated,
      requestContext().correlationId,
    );
    // merchant-service announces the new order to the store's members.
    await this.events.publishEvent(
      QueueName.MerchantJobs,
      EventType.OrderCreated,
      orderCreated,
      requestContext().correlationId,
    );
    await this.notifyCustomer(order, EventType.OrderCreated);
    await this.fanOutToRealtime(order, EventType.OrderCreated);

    try { await this.redis.del(idempotencyKey); } catch { /* Redis unavailable */ }

    this.logger.log(`Order #${order.id} (${order.orderNumber}) created`);
    return order;
  }

  async listByCustomer(customerId: number, page: number, perPage: number): Promise<{ items: Order[]; total: number }> {
    const [items, total] = await this.orders.findAndCount({
      where: { customerId },
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { items, total };
  }

  async byId(id: number): Promise<Order | null> {
    return this.orders.findOne({ where: { id } });
  }

  async listForAdmin(filters: { page: number; perPage: number; status?: string; search?: string; store?: number; customer?: number; payment?: string }) {
    const query = this.orders.createQueryBuilder('order').orderBy('order.id', 'DESC')
      .skip((filters.page - 1) * filters.perPage).take(filters.perPage);
    if (filters.status) query.andWhere('order.status = :status', { status: filters.status });
    if (filters.store) query.andWhere('order.store_id = :store', { store: filters.store });
    if (filters.customer) query.andWhere('order.customer_id = :customer', { customer: filters.customer });
    if (filters.payment) query.andWhere('order.payment_method = :payment', { payment: filters.payment });
    const term = filters.search?.trim();
    if (term) query.andWhere('(order.order_number ILIKE :term OR order.customer_name ILIKE :term OR order.store_name ILIKE :term)', { term: `%${term.replace(/[\\%_]/g, '\\$&')}%` });
    const [items, total] = await query.getManyAndCount();
    return { items, total };
  }

  async require(id: number): Promise<Order> {
    const order = await this.byId(id);
    if (!order) throw new NotFoundException('Order not found.');
    return order;
  }

  async byOrderNumber(orderNumber: string): Promise<Order | null> {
    return this.orders.findOne({ where: { orderNumber } });
  }

  async byDeliveryId(deliveryId: number): Promise<Order | null> {
    return this.orders.findOne({ where: { deliveryId } });
  }

  async itemsForOrder(orderId: number): Promise<OrderItem[]> {
    return this.orderItems.find({ where: { orderId }, order: { id: 'ASC' } });
  }

  async confirm(order: Order): Promise<Order> {
    this.assertTransition(order.status, OrderStatus.Confirmed);
    order.status = OrderStatus.Confirmed;
    const saved = await this.orders.save(order);
    await this.publishStatus(saved, EventType.OrderConfirmed, { orderId: saved.id, orderNumber: saved.orderNumber, status: saved.status });
    return saved;
  }

  async requireForMerchant(id: number, userId: number): Promise<Order> {
    const order = await this.require(id);
    const stores = await this.merchant.get<Array<{ id: number }>>(`/internal/stores/by-user/${userId}`);
    if (!stores.some((store) => store.id === order.storeId)) throw new NotFoundException('Order not found.');
    return order;
  }

  async markPreparing(order: Order): Promise<Order> {
    this.assertTransition(order.status, OrderStatus.Preparing);
    order.status = OrderStatus.Preparing;
    const saved = await this.orders.save(order);
    await this.publishStatus(saved, EventType.OrderPreparing, { orderId: saved.id, orderNumber: saved.orderNumber, status: saved.status });
    return saved;
  }

  async markReadyForPickup(order: Order): Promise<Order> {
    this.assertTransition(order.status, OrderStatus.ReadyForPickup);
    order.status = OrderStatus.ReadyForPickup;
    const saved = await this.orders.save(order);
    await this.publishStatus(saved, EventType.OrderReadyForPickup, { orderId: saved.id, orderNumber: saved.orderNumber, deliveryId: saved.deliveryId });
    return saved;
  }

  async cancel(order: Order, cancelledBy: string, reason?: string): Promise<Order> {
    if (order.status === OrderStatus.Delivered || order.status === OrderStatus.Cancelled) {
      throw new DomainError('Order cannot be cancelled in its current state.');
    }
    order.status = OrderStatus.Cancelled;
    order.cancelledBy = cancelledBy;
    order.cancellationReason = reason ?? null;
    order.cancelledAt = new Date();
    const saved = await this.orders.save(order);
    await this.publishStatus(saved, EventType.OrderCancelled, { orderId: saved.id, orderNumber: saved.orderNumber, cancelledBy, reason });
    return saved;
  }

  async handleDeliveryAssigned(deliveryId: number, riderId: number): Promise<void> {
    const order = await this.byDeliveryId(deliveryId);
    if (!order) return;
    if (order.status !== OrderStatus.ReadyForPickup) return;
    order.status = OrderStatus.RiderAssigned;
    await this.orders.save(order);
    await this.publishStatus(order, EventType.OrderRiderAssigned, { orderId: order.id, orderNumber: order.orderNumber, riderId });
  }

  async handleDeliveryPickedUp(deliveryId: number): Promise<void> {
    const order = await this.byDeliveryId(deliveryId);
    if (!order) return;
    if (order.status !== OrderStatus.RiderAssigned) return;
    order.status = OrderStatus.PickedUp;
    await this.orders.save(order);
    await this.fanOutToRealtime(order, EventType.DeliveryPickedUp);
  }

  async handleDeliveryOutForDelivery(deliveryId: number): Promise<void> {
    const order = await this.byDeliveryId(deliveryId);
    if (!order) return;
    if (order.status !== OrderStatus.PickedUp) return;
    order.status = OrderStatus.OutForDelivery;
    await this.orders.save(order);
    await this.fanOutToRealtime(order, EventType.DeliveryInTransit);
  }

  async handleDeliveryDelivered(deliveryId: number): Promise<void> {
    const order = await this.byDeliveryId(deliveryId);
    if (!order) return;
    if (order.status !== OrderStatus.OutForDelivery && order.status !== OrderStatus.PickedUp) return;
    order.status = OrderStatus.Delivered;
    order.paymentStatus = PaymentStatus.Paid;
    await this.orders.save(order);
    await this.publishStatus(order, EventType.OrderDelivered, { orderId: order.id, orderNumber: order.orderNumber });
  }

  async handleDeliveryCancelled(deliveryId: number, cancelledBy: string, reason?: string): Promise<void> {
    const order = await this.byDeliveryId(deliveryId);
    if (!order) return;
    if (order.status === OrderStatus.Delivered || order.status === OrderStatus.Cancelled) return;
    order.status = OrderStatus.Cancelled;
    order.cancelledBy = cancelledBy;
    order.cancellationReason = reason ?? null;
    order.cancelledAt = new Date();
    await this.orders.save(order);
    await this.publishStatus(order, EventType.OrderCancelled, { orderId: order.id, orderNumber: order.orderNumber, cancelledBy, reason });
  }

  /**
   * Mirror payment-service's payment state onto the order and notify the
   * customer. Driven by `payment-events` (see PaymentEventsConsumer).
   */
  async handlePaymentChanged(
    payload: { orderId: number; amount: string; status: string },
    status: PaymentStatus,
  ): Promise<void> {
    const order = await this.orders.findOne({ where: { id: payload.orderId } });
    if (!order) return;
    // A late payment event must not resurrect a settled order's state, and
    // re-applying the same status would spam duplicate notifications.
    if (order.status === OrderStatus.Cancelled) return;
    if (order.paymentStatus === status) return;

    order.paymentStatus = status;
    await this.orders.save(order);

    const copy: Record<PaymentStatus, { type: string; title: string; body: string }> = {
      [PaymentStatus.Pending]: {
        type: 'payment.pending',
        title: 'Payment pending',
        body: `Your payment for order ${order.orderNumber} is pending.`,
      },
      [PaymentStatus.Paid]: {
        type: 'payment.paid',
        title: 'Payment received',
        body: `We received your payment for order ${order.orderNumber}.`,
      },
      [PaymentStatus.Failed]: {
        type: 'payment.failed',
        title: 'Payment failed',
        body: `The payment for order ${order.orderNumber} could not be completed.`,
      },
      [PaymentStatus.Refunded]: {
        type: 'payment.refunded',
        title: 'Payment refunded',
        body: `Your payment for order ${order.orderNumber} has been refunded.`,
      },
    };
    const message = copy[status];
    await this.events.publishEvent(
      QueueName.NotificationJobs,
      EventType.NotificationCreate,
      {
        userId: order.customerId,
        type: message.type,
        title: message.title,
        body: message.body,
        data: { orderId: order.id, orderNumber: order.orderNumber, amount: payload.amount },
      },
      requestContext().correlationId,
    );
    const paymentEvent = status === PaymentStatus.Paid ? EventType.PaymentPaid
      : status === PaymentStatus.Refunded ? EventType.PaymentRefunded
      : status === PaymentStatus.Failed ? EventType.PaymentFailed : EventType.PaymentCreated;
    await this.fanOutToRealtime(order, paymentEvent);
  }

  async adminTotals(): Promise<{ orders: number; pendingOrders: number; todayOrders: number; todayDelivered: number; todayRevenue: string }> {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start.getTime() + 86400000);

    const [orders, pendingOrders, todayOrders, todayDelivered, todayRevenue] = await Promise.all([
      this.orders.count(),
      this.orders.count({ where: { status: OrderStatus.Pending } }),
      this.orders.count({ where: { createdAt: Between(start, end) } }),
      this.orders.count({ where: { status: OrderStatus.Delivered, updatedAt: Between(start, end) } }),
      this.todayRevenue(start, end),
    ]);

    return { orders, pendingOrders, todayOrders, todayDelivered, todayRevenue };
  }

  private async todayRevenue(start: Date, end: Date): Promise<string> {
    const rows = await this.orders.find({
      where: { status: OrderStatus.Delivered, updatedAt: Between(start, end) },
      select: ['total'],
    });
    const totalMinor = rows.reduce((sum, row) => sum + toMinor(row.total), 0);
    return fromMinor(totalMinor);
  }

  private assertTransition(current: string, next: string): void {
    const allowed = ORDER_TRANSITIONS[current as OrderStatus];
    if (!allowed || !allowed.includes(next as OrderStatus)) {
      throw new DomainError(`Order cannot transition from ${current} to ${next}.`);
    }
  }

  /**
   * Types dispatch acts on. `order-events` is dispatch's queue and it is the
   * only consumer, so publishing anything else there produces a job it claims
   * and throws away. Other audiences get their own queue (see
   * `notifyCustomer` and the `MerchantJobs` fan-out in `create`).
   */
  private static readonly DISPATCH_HANDLED: ReadonlySet<string> = new Set([
    EventType.OrderReadyForPickup,
    EventType.OrderCancelled,
  ]);

  /** Status changes worth pushing to the store and customer in real time. */
  private static readonly REALTIME_TYPES: ReadonlySet<string> = new Set([
    EventType.OrderCreated,
    EventType.DeliveryPickedUp,
    EventType.DeliveryInTransit,
    EventType.PaymentPaid,
    EventType.PaymentFailed,
    EventType.PaymentRefunded,
    EventType.PaymentCreated,
    EventType.OrderConfirmed,
    EventType.OrderPreparing,
    EventType.OrderReadyForPickup,
    EventType.OrderCancelled,
    EventType.OrderRiderAssigned,
    EventType.OrderDelivered,
  ]);

  /** Order types merchant-service turns into store-member notifications. */
  private static readonly MERCHANT_HANDLED: ReadonlySet<string> = new Set([
    EventType.OrderReadyForPickup,
    EventType.OrderCancelled,
    EventType.OrderDelivered,
  ]);

  private async publishStatus(order: Order, eventType: string, data: Record<string, unknown>): Promise<void> {
    if (OrderService.DISPATCH_HANDLED.has(eventType)) {
      await this.events.publishEvent(
        QueueName.OrderEvents,
        eventType,
        data,
        requestContext().correlationId,
      );
    }
    if (OrderService.MERCHANT_HANDLED.has(eventType)) {
      await this.events.publishEvent(
        QueueName.MerchantJobs,
        eventType,
        {
          ...data,
          storeId: order.storeId,
          customerId: order.customerId,
          total: order.total,
          status: order.status,
        },
        requestContext().correlationId,
      );
    }
    await this.notifyCustomer(order, eventType);
    await this.fanOutToRealtime(order, eventType);
  }

  /**
   * Push the status change to the Socket.IO rooms that care.
   *
   * The store, the customer, and the order's own room are all interested, and
   * none of them can subscribe to a queue: realtime-service is the consumer of
   * `realtime-feed` and the publisher has to name the audience.
   */
  private async fanOutToRealtime(order: Order, eventType: string): Promise<void> {
    if (!OrderService.REALTIME_TYPES.has(eventType)) return;
    const rooms = [
      'admin:platform',
      `order:${order.id}`,
      `user:${order.customerId}`,
      `customer:${order.customerId}`,
      `merchant:${order.storeId}`,
    ];
    await this.events.publishEvent(
      QueueName.RealtimeFeed,
      EventType.RealtimeEmit,
      {
        rooms,
        event: 'order.updated',
        data: {
          orderId: order.id,
          orderNumber: order.orderNumber,
          storeId: order.storeId,
          customerId: order.customerId,
          deliveryId: order.deliveryId,
          status: order.status,
          paymentStatus: order.paymentStatus,
          total: order.total,
          eventType,
          updatedAt: new Date().toISOString(),
        },
      },
      requestContext().correlationId,
    );
  }

  /**
   * Emit a `notification.create` for the customer on order status changes.
   *
   * `order-events` is dispatch's queue and only carries the types dispatch
   * acts on (`ready_for_pickup`, `cancelled`); the rest of the lifecycle has no
   * subscriber. order-service owns the customer reference, so it is the right
   * place to turn its own transitions into notifications.
   */
  private async notifyCustomer(order: Order, eventType: string): Promise<void> {
    const copy: Record<string, { type: string; title: string; body: string } | undefined> = {
      [EventType.OrderCreated]: {
        type: 'order.created',
        title: 'Order placed',
        body: `We received your order ${order.orderNumber}.`,
      },
      [EventType.OrderConfirmed]: {
        type: 'order.confirmed',
        title: 'Order confirmed',
        body: `${order.storeName || 'The store'} confirmed your order ${order.orderNumber}.`,
      },
      [EventType.OrderPreparing]: {
        type: 'order.preparing',
        title: 'Order being prepared',
        body: `Your order ${order.orderNumber} is being prepared.`,
      },
      [EventType.OrderReadyForPickup]: {
        type: 'order.ready_for_pickup',
        title: 'Waiting for your rider',
        body: `Your order ${order.orderNumber} is ready and a rider is being assigned.`,
      },
      [EventType.OrderDelivered]: {
        type: 'order.delivered',
        title: 'Order delivered',
        body: `Your order ${order.orderNumber} has been delivered.`,
      },
      [EventType.OrderCancelled]: {
        type: 'order.cancelled',
        title: 'Order cancelled',
        body: `Your order ${order.orderNumber} was cancelled.`,
      },
    };
    const message = copy[eventType];
    if (message === undefined) return;

    await this.events.publishEvent(
      QueueName.NotificationJobs,
      EventType.NotificationCreate,
      {
        userId: order.customerId,
        type: message.type,
        title: message.title,
        body: message.body,
        data: { orderId: order.id, orderNumber: order.orderNumber, status: order.status },
      },
      requestContext().correlationId,
    );
  }

  private generateOrderNumber(): string {
    const now = new Date();
    const ymd = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
    const random = Math.random().toString(36).slice(2, 8).toUpperCase();
    return `TLD-${ymd}-${random}`;
  }

  private async checkIdempotency(customerId: number, dto: CreateOrderDto): Promise<string> {
    const itemsHash = dto.items.map((i) => `${i.productId}:${i.quantity}`).sort().join('|');
    const key = `${IdempotencyKeyPrefix.OrderCreate}${customerId}:${itemsHash}`;
    try {
      const existing = await this.redis.get(key);
      if (existing) throw new ConflictException('Duplicate order request detected.');
      await this.redis.set(key, '1', 'EX', 3600);
    } catch (error) {
      if (error instanceof ConflictException) throw error;
      this.logger.warn('Redis unavailable, skipping idempotency check');
    }
    return key;
  }
}
