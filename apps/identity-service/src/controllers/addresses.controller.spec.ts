jest.mock('@taladelivery/auth', () => ({
  AppKeyGuard: class {}, JwtAuthGuard: class {}, RolesGuard: class {},
  CurrentUser: () => () => undefined, Roles: () => () => undefined,
}));
import { AddressesController } from './addresses.controller';

describe('Customer address ownership', () => {
  const user = { sub: 7 } as any;
  it('lists only the current customer addresses without exposing userId', async () => {
    const find = jest.fn().mockResolvedValue([{ id: 1, userId: 7 }]);
    expect(await new AddressesController({ find } as any).list(user)).toEqual([{ id: 1 }]);
    expect(find.mock.calls[0][0].where).toEqual({ userId: 7 });
  });
  it('cannot delete another customer address', async () => {
    const remove = jest.fn().mockResolvedValue({ affected: 0 });
    await expect(new AddressesController({ delete: remove } as any).remove(user, 9)).rejects.toThrow('Address not found');
    expect(remove).toHaveBeenCalledWith({ id: 9, userId: 7 });
  });
  it('cannot update another customer address', async () => {
    const findOneBy = jest.fn().mockResolvedValue(null);
    const manager = { query: jest.fn(), getRepository: () => ({ findOneBy }) };
    const controller = new AddressesController({ manager: { transaction: (callback: any) => callback(manager) } } as any);
    await expect(controller.update(user, 9, {} as any)).rejects.toThrow('Address not found');
    expect(findOneBy).toHaveBeenCalledWith({ id: 9, userId: 7 });
  });
});
