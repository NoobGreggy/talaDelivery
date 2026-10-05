import { LocationEventsConsumer } from './location-events.consumer';
import { EventType, QueueName } from '@taladelivery/events';

describe('Authenticated dispatch location feed', () => {
  it('uses separate order, delivery and rider IDs and sends Flutter fields', async () => {
    let handler: (data: unknown) => Promise<void>;
    const worker = { on: jest.fn(async (_queue, callback) => { handler = callback; }) };
    const gateway = { emitToRoom: jest.fn() };
    const consumer = new LocationEventsConsumer(worker as never, gateway as never);
    await consumer.onModuleInit();
    expect(worker.on).toHaveBeenCalledWith(QueueName.LocationEvents, expect.any(Function), { eventTypes: [EventType.RiderLocationUpdated] });
    await handler!({ orderId: 31, deliveryId: 22, riderId: 4, latitude: '16.9452', longitude: '121.7662', accuracyM: 7, headingDeg: 90, speedMps: 5, recordedAt: '2026-10-06T01:00:00Z' });
    expect(gateway.emitToRoom.mock.calls.map(([room]) => room)).toEqual(['delivery:22', 'order:31', 'rider:4']);
    expect(gateway.emitToRoom).toHaveBeenCalledWith('delivery:22', 'rider.location', expect.objectContaining({ latitude: 16.9452, longitude: 121.7662, accuracyM: 7, timestamp: '2026-10-06T01:00:00Z' }));
  });
});
jest.mock('@taladelivery/auth', () => ({ TokenService: class {} }));
jest.mock('@nestjs/websockets', () => Object.fromEntries(['ConnectedSocket', 'MessageBody', 'SubscribeMessage', 'WebSocketGateway', 'WebSocketServer'].map((name) => [name, () => () => undefined])));
