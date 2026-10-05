import { Repository, SelectQueryBuilder } from 'typeorm';
import { Store } from '../entities/store.entity';
import { StoreService } from './store.service';

function seedStore(overrides: Partial<Store> = {}): Store {
  const store = new Store();
  Object.assign(store, {
    id: 1,
    name: 'Test Store',
    slug: 'test-store',
    status: 'ACTIVE',
    address: null,
    phone: null,
    latitude: null,
    longitude: null,
    openingHours: null,
    createdAt: new Date('2026-09-29T00:00:00.000Z'),
    updatedAt: new Date('2026-09-29T00:00:00.000Z'),
    ...overrides,
  });
  return store;
}

type QbStub = {
  leftJoinAndSelect: jest.Mock;
  andWhere: jest.Mock;
  orderBy: jest.Mock;
  skip: jest.Mock;
  take: jest.Mock;
  getManyAndCount: jest.Mock;
};

/**
 * Fakes the query builder used by `paginate`, plus the find/findOne paths the
 * public list and slug uniqueness rely on.
 */
function repoStub(rows: Store[]) {
  const qb: QbStub = {
    leftJoinAndSelect: jest.fn(),
    andWhere: jest.fn(),
    orderBy: jest.fn(),
    skip: jest.fn(),
    take: jest.fn(),
    getManyAndCount: jest.fn(async () => [rows, rows.length]),
  };
  for (const method of ['leftJoinAndSelect', 'andWhere', 'orderBy', 'skip', 'take'] as const) {
    qb[method].mockReturnValue(qb);
  }

  const repo = {
    createQueryBuilder: jest.fn(() => qb),
    find: jest.fn(async (options: { where?: Partial<Store> } = {}) => {
      const where = options.where ?? {};
      return rows.filter((row) =>
        Object.entries(where).every(([key, value]) => (row as unknown as Record<string, unknown>)[key] === value),
      );
    }),
    findOne: jest.fn(async ({ where }: { where: Partial<Store> }) =>
      rows.find((row) =>
        Object.entries(where).every(([key, value]) => (row as unknown as Record<string, unknown>)[key] === value),
      ) ?? null,
    ),
    exists: jest.fn(async ({ where }: { where: Partial<Store> }) =>
      rows.some((row) => Object.entries(where).every(([key, value]) => (row as unknown as Record<string, unknown>)[key] === value)),
    ),
    create: jest.fn((data: Partial<Store>) => ({ ...data }) as Store),
    save: jest.fn(async (store: Store) => {
      if (store.id === undefined) store.id = rows.length + 1;
      const index = rows.findIndex((row) => row.id === store.id);
      if (index === -1) rows.push(store);
      else rows[index] = store;
      return store;
    }),
  };

  return { repo: repo as unknown as Repository<Store>, storeUserRepo: {} as never, qb };
}

function setup(rows: Store[] = []) {
  const stub = repoStub(rows);
  const service = new StoreService(stub.repo, stub.storeUserRepo);
  return { service, qb: stub.qb, rows };
}

describe('StoreService.list', () => {
  it('returns ACTIVE stores only', async () => {
    const { service, rows } = setup([
      seedStore({ id: 1, status: 'ACTIVE' }),
      seedStore({ id: 2, status: 'SUSPENDED' }),
      seedStore({ id: 3, status: 'ACTIVE' }),
    ]);

    const result = await service.list();

    expect(result.map((store) => store.id)).toEqual([1, 3]);
  });
});

describe('StoreService.paginate', () => {
  it('returns the page and total', async () => {
    const { service } = setup([seedStore({ id: 1 }), seedStore({ id: 2 })]);

    const result = await service.paginate({ page: 1, perPage: 15 });

    expect(result.items).toHaveLength(2);
    expect(result.total).toBe(2);
  });

  it('does not constrain by status when none is given', async () => {
    const { service, qb } = setup([seedStore({ status: 'SUSPENDED' })]);

    await service.paginate({ page: 1, perPage: 15 });

    // No status clause at all: the admin list must be able to see non-ACTIVE
    // stores, which the public `list()` can never return.
    expect(qb.andWhere).not.toHaveBeenCalled();
  });

  it('filters by status when provided', async () => {
    const { service, qb } = setup([seedStore()]);

    await service.paginate({ page: 1, perPage: 15, status: 'SUSPENDED' });

    expect(qb.andWhere).toHaveBeenCalledWith('store.status = :status', { status: 'SUSPENDED' });
  });

  it('treats a blank status as no filter', async () => {
    const { service, qb } = setup([seedStore()]);

    await service.paginate({ page: 1, perPage: 15, status: '' });

    expect(qb.andWhere).not.toHaveBeenCalled();
  });

  it('searches name, slug and address', async () => {
    const { service, qb } = setup([seedStore()]);

    await service.paginate({ page: 1, perPage: 15, search: 'test' });

    expect(qb.andWhere).toHaveBeenCalledWith(
      '(store.name ILIKE :term OR store.slug ILIKE :term OR store.address ILIKE :term)',
      { term: '%test%' },
    );
  });

  it('converts page/perPage into skip/take', async () => {
    const { service, qb } = setup([seedStore()]);

    await service.paginate({ page: 4, perPage: 20 });

    expect(qb.skip).toHaveBeenCalledWith(60);
    expect(qb.take).toHaveBeenCalledWith(20);
  });
});
