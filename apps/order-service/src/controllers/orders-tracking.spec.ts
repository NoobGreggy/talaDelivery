import { OrdersController } from './orders.controller';

describe('Customer order tracking snapshot', () => {
  const order = { id: 31, customerId: 7, deliveryId: 22 };
  function harness() {
    const orders = { require: jest.fn(async () => order), itemsForOrder: jest.fn(async () => []),
      deliveryTracking: jest.fn(async () => ({ id: 22, order_id: 31, status: 'ASSIGNED', rider_location: null })) };
    return { orders, controller: new OrdersController(orders as never) };
  }
  it('hydrates the delivery on a customer-owned order', async () => {
    const h = harness();
    expect(await h.controller.show({ sub: 7 } as never, 31)).toMatchObject({ delivery: { id: 22, status: 'ASSIGNED' } });
    expect(h.orders.deliveryTracking).toHaveBeenCalledWith(order);
  });
  it('checks ownership before looking up any location', async () => {
    const h = harness();
    await expect(h.controller.show({ sub: 8 } as never, 31)).rejects.toThrow('Order not found.');
    expect(h.orders.deliveryTracking).not.toHaveBeenCalled();
  });
});
jest.mock('@taladelivery/auth', () => ({ AppKeyGuard: class {}, JwtAuthGuard: class {}, RolesGuard: class {},
  CurrentUser: () => () => undefined, Roles: () => () => undefined }));
