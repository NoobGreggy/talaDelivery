import { RealtimeGateway } from './realtime.gateway';
import { Role } from '@taladelivery/contracts';
describe('Merchant socket room scope', () => {
  const gateway = new RealtimeGateway({} as never, { create: () => ({ get: async () => [{ id: 1 }] }) } as never);
  it('accepts a verified store member', async () => {
    const socket = { user: { sub: 1, role: Role.StoreAdmin }, join: jest.fn() };
    expect(await gateway.handleSubscribe(socket as never, { room: 'merchant:1' })).toEqual({ success: true });
    expect(socket.join).toHaveBeenCalledWith('merchant:1');
  });
  it('rejects another merchant room', async () => {
    const socket = { user: { sub: 1, role: Role.StoreAdmin }, join: jest.fn() };
    expect(await gateway.handleSubscribe(socket as never, { room: 'merchant:2' })).toEqual({ success: false, error: 'Forbidden.' });
    expect(socket.join).not.toHaveBeenCalled();
  });
});
describe('Rider socket user room scope', () => {
  const gateway = new RealtimeGateway({} as never, {} as never);
  it('allows only the authenticated rider identity user room', async () => {
    const socket = { user: { sub: 50, role: Role.Rider }, join: jest.fn() };
    expect(await gateway.handleSubscribe(socket as never, { room: 'user:50' })).toEqual({ success: true });
    expect(await gateway.handleSubscribe(socket as never, { room: 'user:51' })).toEqual({ success: false, error: 'Forbidden.' });
    expect(await gateway.handleSubscribe(socket as never, { room: 'admin:platform' })).toEqual({ success: false, error: 'Forbidden.' });
    expect(socket.join).toHaveBeenCalledTimes(1);
  });
});
jest.mock('@taladelivery/auth', () => ({
  AppKeyGuard: class {}, JwtAuthGuard: class {}, RolesGuard: class {}, TokenService: class {},
  CurrentUser: () => () => undefined, Roles: () => () => undefined,
}));

describe('Delivery tracking room ownership', () => {
  function harness(role: Role = Role.Customer, sub = 7) {
    const get = jest.fn(async (path: string): Promise<unknown> => {
      if (path.startsWith('/internal/orders/')) return { id: 31, customerId: 7, storeId: 2, deliveryId: 22 };
      if (path.startsWith('/internal/deliveries/')) return { id: 22, riderId: 4 };
      if (path.startsWith('/internal/riders/')) return { id: 4 };
      return [{ id: 2 }];
    });
    const gateway = new RealtimeGateway({} as never, { create: () => ({ get }) } as never);
    const socket = { user: { sub, role }, join: jest.fn() };
    return { get, gateway, socket };
  }
  it('resolves a delivery to its order; IDs are not interchangeable', async () => {
    const h = harness();
    expect(await h.gateway.handleSubscribe(h.socket as never, { room: 'delivery:22' })).toEqual({ success: true });
    expect(h.get).toHaveBeenCalledWith('/internal/orders/by-delivery/22');
  });
  it('rejects another customer and does not join', async () => {
    const h = harness(Role.Customer, 8);
    expect((await h.gateway.handleSubscribe(h.socket as never, { room: 'order:31' })).success).toBe(false);
    expect(h.socket.join).not.toHaveBeenCalled();
  });
  it('allows only the assigned rider', async () => {
    const h = harness(Role.Rider, 50);
    expect((await h.gateway.handleSubscribe(h.socket as never, { room: 'delivery:22' })).success).toBe(true);
    h.get.mockImplementation(async (path) => path.includes('/orders/')
      ? { id: 31, customerId: 7, storeId: 2, deliveryId: 22 }
      : path.includes('/deliveries/') ? { id: 22, riderId: 99 } : { id: 4 } as never);
    expect((await h.gateway.handleSubscribe(h.socket as never, { room: 'delivery:22' })).success).toBe(false);
  });
  it('limits rider location rooms to the rider profile ID, not identity ID', async () => {
    const h = harness(Role.Rider, 50);
    expect((await h.gateway.handleSubscribe(h.socket as never, { room: 'rider:4' })).success).toBe(true);
    expect((await h.gateway.handleSubscribe(h.socket as never, { room: 'rider:50' })).success).toBe(false);
  });
  it('fails closed on unavailable ownership lookup and malformed rooms', async () => {
    const h = harness(); h.get.mockRejectedValue(new Error('unavailable'));
    for (const room of ['delivery:22', 'delivery:0', 'order:NaN', 'order:-1', 'order:31x']) {
      expect((await h.gateway.handleSubscribe(h.socket as never, { room })).success).toBe(false);
    }
    expect(h.socket.join).not.toHaveBeenCalled();
  });
  it('requires location updates to use dispatch validation', async () => {
    const h = harness(Role.Rider, 50);
    expect((await h.gateway.handleLocationUpdate(h.socket as never, { deliveryId: 22, latitude: 14.6, longitude: 121 })).success).toBe(false);
  });
});
jest.mock('@nestjs/websockets', () => Object.fromEntries(['ConnectedSocket', 'MessageBody', 'SubscribeMessage', 'WebSocketGateway', 'WebSocketServer'].map((name) => [name, () => () => undefined])));
