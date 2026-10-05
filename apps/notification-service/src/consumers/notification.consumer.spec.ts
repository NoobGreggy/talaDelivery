import { NotificationConsumer } from './notification.consumer';
import { EventType, QueueName } from '@taladelivery/events';

describe('Persisted order notifications', () => {
  it('persists before broadcasting to only the recipient room', async () => {
    let handler: (data: unknown, envelope: { eventId: string; correlationId: string }) => Promise<void>;
    const calls: string[] = [];
    const worker = { on: jest.fn(async (_queue, callback) => { handler = callback; }) };
    const notifications = { create: jest.fn(async (input) => {
      calls.push('persist'); return { ...input, id: 42, isRead: false, createdAt: new Date() };
    }) };
    const events = { publishEvent: jest.fn(async () => { calls.push('broadcast'); }) };
    const consumer = new NotificationConsumer(worker as never, notifications as never, events as never);
    await consumer.onModuleInit();
    await handler!({ userId: 7, type: 'order.received', title: 'New order received', body: 'Order TALA-1', data: { orderId: 1 } },
      { eventId: 'event-1', correlationId: 'correlation-1' });
    expect(calls).toEqual(['persist', 'broadcast']);
    expect(notifications.create).toHaveBeenCalledWith(expect.objectContaining({ sourceKey: 'notification-event-event-1' }));
    expect(events.publishEvent).toHaveBeenCalledWith(QueueName.RealtimeFeed, EventType.RealtimeEmit,
      expect.objectContaining({ rooms: ['user:7'], event: 'notification.created', data: expect.objectContaining({ id: 42, type: 'order.received' }) }), 'correlation-1');
  });
});
