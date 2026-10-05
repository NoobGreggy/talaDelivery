import { StoreOrdersController } from './store-orders.controller';
import { OrderStatus } from '@taladelivery/contracts';

function harness() {
  const order = { id: 9, storeId: 1, status: OrderStatus.Pending, deliveryId: null,
    subtotal: '50.00', total: '60.00', deliveryFee: '10.00', createdAt: new Date(), updatedAt: new Date() };
  const orders = { require: jest.fn(async () => order), listForAdmin: jest.fn(async () => ({ items: [order], total: 1 })),
    itemsForOrder: jest.fn(async () => [{ id: 1, productId: 2, productName: 'Rice', unitPrice: '50.00', subtotal: '50.00', quantity: 1 }]),
    confirm: jest.fn(async () => ({ ...order, status: OrderStatus.Confirmed })),
    markPreparing: jest.fn(async () => order), markReadyForPickup: jest.fn(async () => order), cancel: jest.fn(async () => order) };
  const merchant = { get: jest.fn(async () => [{ id: 1 }, { id: 2 }]) };
  const controller = new StoreOrdersController(orders as never, { create: () => merchant } as never);
  return { controller, orders, order, merchant, user: { sub: 7 } as never };
}
describe('Store order API', () => {
  it('uses verified store membership, not a store query supplied by the caller', async () => {
    const h = harness();
    await h.controller.list(h.user, '1', { store: 99, page: 1, per_page: 5 });
    expect(h.orders.listForAdmin).toHaveBeenCalledWith(expect.objectContaining({ store: 1, perPage: 5 }));
  });
  it('rejects another store header before querying orders', async () => {
    const h = harness();
    await expect(h.controller.list(h.user, '99', {})).rejects.toThrow('Store membership not found');
    expect(h.orders.listForAdmin).not.toHaveBeenCalled();
  });
  it('rejects another store order before any mutation', async () => {
    const h = harness(); h.order.storeId = 99;
    await expect(h.controller.confirm(h.user, '1', 9)).rejects.toThrow('Order not found');
    expect(h.orders.confirm).not.toHaveBeenCalled();
  });
  it('returns UI field names, numeric money and items after a transition', async () => {
    const h = harness(); const result = await h.controller.confirm(h.user, '1', 9);
    expect(result.status).toBe(OrderStatus.Confirmed);
    expect(result.total).toBe(60);
    expect(result.items[0]).toMatchObject({ product: { name: 'Rice' }, price: 50 });
  });
  it.each(['preparing', 'ready', 'cancel'] as const)('checks ownership before %s', async (action) => {
    const h = harness(); h.order.storeId = 99;
    await expect(action === 'cancel' ? h.controller.cancel(h.user, '1', 9, {}) : h.controller[action](h.user, '1', 9))
      .rejects.toThrow('Order not found');
  });
});
jest.mock('@taladelivery/auth', () => ({
  AppKeyGuard: class {}, JwtAuthGuard: class {}, RolesGuard: class {}, TokenService: class {},
  CurrentUser: () => () => undefined, Roles: () => () => undefined,
}));
