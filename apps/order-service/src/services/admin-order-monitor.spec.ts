import { OrderStatus, PaymentStatus } from '@taladelivery/contracts';
import { EventType, QueueName } from '@taladelivery/events';
import { OrderService } from './order.service';
import { Order } from '../entities/order.entity';

function harness(status: string) {
  const order = { id: 1, orderNumber: 'TALA-001', status, paymentStatus: PaymentStatus.Pending,
    storeId: 2, customerId: 3, deliveryId: 4, total: '100.00' } as Order;
  const query = { orderBy: jest.fn(), skip: jest.fn(), take: jest.fn(), andWhere: jest.fn(),
    getManyAndCount: jest.fn(async () => [[order], 1]) };
  for (const method of ['orderBy', 'skip', 'take', 'andWhere'] as const) query[method].mockReturnValue(query);
  const repository = { findOne: jest.fn(async () => order), save: jest.fn(async (value) => value), createQueryBuilder: jest.fn(() => query) };
  const events = { publishEvent: jest.fn(async () => undefined) };
  // Monitoring/event tests do not require opening Redis connections used for checkout.
  const service: OrderService = Object.assign(Object.create(OrderService.prototype), { orders: repository, events });
  return { service, order, query, events };
}

describe('Admin order monitoring', () => {
  it('lists all statuses by default and paginates on the server', async () => {
    const h = harness(OrderStatus.Delivered);
    const result = await h.service.listForAdmin({ page: 2, perPage: 20 });
    expect(h.query.skip).toHaveBeenCalledWith(20);
    expect(h.query.take).toHaveBeenCalledWith(20);
    expect(h.query.andWhere).not.toHaveBeenCalled();
    expect(result.total).toBe(1);
  });
  it('applies status, search, store, customer and payment filters before pagination', async () => {
    const h = harness(OrderStatus.Pending);
    await h.service.listForAdmin({ page: 1, perPage: 20, status: 'PENDING', search: 'TALA-001', store: 2, customer: 3, payment: 'COD' });
    expect(h.query.andWhere).toHaveBeenCalledWith('order.status = :status', { status: 'PENDING' });
    expect(h.query.andWhere).toHaveBeenCalledWith('order.store_id = :store', { store: 2 });
    expect(h.query.andWhere).toHaveBeenCalledWith('order.customer_id = :customer', { customer: 3 });
    expect(h.query.andWhere).toHaveBeenCalledWith('order.payment_method = :payment', { payment: 'COD' });
    expect(h.query.andWhere).toHaveBeenCalledWith(expect.stringContaining('ILIKE'), { term: '%TALA-001%' });
  });
  it('broadcasts picked-up status to platform admins', async () => {
    const h = harness(OrderStatus.RiderAssigned);
    await h.service.handleDeliveryPickedUp(4);
    expect(h.order.status).toBe(OrderStatus.PickedUp);
    expect(h.events.publishEvent).toHaveBeenCalledWith(QueueName.RealtimeFeed, EventType.RealtimeEmit,
      expect.objectContaining({ rooms: expect.arrayContaining(['admin:platform']), event: 'order.updated',
        data: expect.objectContaining({ status: OrderStatus.PickedUp, orderId: 1 }) }), expect.any(String));
  });
  it('broadcasts out-for-delivery status to platform admins', async () => {
    const h = harness(OrderStatus.PickedUp);
    await h.service.handleDeliveryOutForDelivery(4);
    expect(h.order.status).toBe(OrderStatus.OutForDelivery);
    expect(h.events.publishEvent).toHaveBeenCalledWith(QueueName.RealtimeFeed, EventType.RealtimeEmit,
      expect.objectContaining({ rooms: expect.arrayContaining(['admin:platform']),
        data: expect.objectContaining({ status: OrderStatus.OutForDelivery }) }), expect.any(String));
  });
  it('broadcasts delivered status and payment status to platform admins', async () => {
    const h = harness(OrderStatus.OutForDelivery);
    await h.service.handleDeliveryDelivered(4);
    expect(h.order.status).toBe(OrderStatus.Delivered);
    expect(h.events.publishEvent).toHaveBeenCalledWith(QueueName.RealtimeFeed, EventType.RealtimeEmit,
      expect.objectContaining({ rooms: expect.arrayContaining(['admin:platform']),
        data: expect.objectContaining({ status: OrderStatus.Delivered, paymentStatus: PaymentStatus.Paid }) }), expect.any(String));
  });
  it('ignores a duplicate picked-up event instead of broadcasting the transition twice', async () => {
    const h = harness(OrderStatus.PickedUp);
    await h.service.handleDeliveryPickedUp(4);
    expect(h.events.publishEvent).not.toHaveBeenCalled();
  });
});
