import { OrderEventsConsumer } from './order-events.consumer';
import { EventType, QueueName } from '@taladelivery/events';

describe('Merchant new order alerts', () => {
  it('notifies all and only members of the ordering store', async () => {
    let handler: (data: unknown, envelope: { eventType: string }) => Promise<void>;
    const members = { find: jest.fn(async () => [{ userId: 7 }, { userId: 8 }]) };
    const worker = { on: jest.fn(async (_queue, callback) => { handler = callback; }) };
    const events = { publishEvent: jest.fn(async () => undefined) };
    const consumer = new OrderEventsConsumer(members as never, worker as never, events as never);
    await consumer.onModuleInit();
    await handler!({ orderId: 1, orderNumber: 'TALA-1', storeId: 2, customerId: 3, total: '150.00' }, { eventType: EventType.OrderCreated });
    expect(members.find).toHaveBeenCalledWith({ where: { storeId: 2 } });
    expect(events.publishEvent).toHaveBeenCalledTimes(2);
    for (const userId of [7, 8]) expect(events.publishEvent).toHaveBeenCalledWith(QueueName.NotificationJobs, EventType.NotificationCreate,
      expect.objectContaining({ userId, type: 'order.received', title: 'New order received', data: expect.objectContaining({ orderId: 1, storeId: 2 }) }));
  });
});
