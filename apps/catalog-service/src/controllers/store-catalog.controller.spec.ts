import { StoreCatalogController } from './store-catalog.controller';

describe('Store catalog ownership', () => {
  const user = { sub: 1 } as never;
  function harness() {
    const products = { require: jest.fn(async () => ({ storeId: 2 })), update: jest.fn(), remove: jest.fn() };
    const categories = { require: jest.fn(async () => ({ storeId: 2 })), update: jest.fn(), remove: jest.fn() };
    const controller = new StoreCatalogController(products as never, categories as never,
      { create: () => ({ get: async () => [{ id: 1 }] }) } as never);
    return { products, categories, controller };
  }
  it('rejects an unowned store header', async () => {
    await expect(harness().controller.storeId(1, '2')).rejects.toThrow('Store membership not found');
  });
  it('cannot change another store product', async () => {
    const h = harness(); await expect(h.controller.updateProduct(user, '1', 8, { name: 'Changed' })).rejects.toThrow('Product not found');
    expect(h.products.update).not.toHaveBeenCalled();
  });
  it('cannot delete another store category', async () => {
    const h = harness(); await expect(h.controller.deleteCategory(user, '1', 8)).rejects.toThrow('Category not found');
    expect(h.categories.remove).not.toHaveBeenCalled();
  });
  it('cannot create a product tagged with another store category', async () => {
    const h = harness(); await expect(h.controller.createProduct(user, '1', { name: 'Rice', price: 50, category_id: 8 })).rejects.toThrow('Category not found');
  });
});
jest.mock('@taladelivery/auth', () => ({
  AppKeyGuard: class {}, JwtAuthGuard: class {}, RolesGuard: class {}, TokenService: class {},
  CurrentUser: () => () => undefined, Roles: () => () => undefined,
}));
