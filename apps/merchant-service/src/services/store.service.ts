import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { StoreSnapshot, StoreStatus } from '@taladelivery/contracts';
import { Repository } from 'typeorm';
import { CreateStoreDto, UpdateStoreDto } from '../dto/store.dto';
import { Store } from '../entities/store.entity';
import { StoreUser } from '../entities/store-user.entity';

@Injectable()
export class StoreService {
  constructor(
    @InjectRepository(Store) private readonly stores: Repository<Store>,
    @InjectRepository(StoreUser) private readonly storeUsers: Repository<StoreUser>,
  ) {}

  async list(categoryId?: number): Promise<Store[]> {
    const stores = await this.stores.find({ where: { status: StoreStatus.Active }, order: { id: 'DESC' } });
    return categoryId == null ? stores : stores.filter((store) => store.categories?.some((category) => category.id === categoryId && category.isActive));
  }

  /**
   * Paginated admin listing. Unlike `list()` this spans every status — the
   * public endpoint can only ever expose ACTIVE stores, but an admin console
   * must be able to find a SUSPENDED store in order to reactivate it.
   * Newest first, matching the public list's ordering.
   */
  async paginate(opts: { page: number; perPage: number; search?: string; status?: string }): Promise<{ items: Store[]; total: number }> {
    const query = this.stores.createQueryBuilder('store')
      .leftJoinAndSelect('store.categories', 'category')
      .orderBy('store.id', 'DESC')
      .skip((opts.page - 1) * opts.perPage)
      .take(opts.perPage);

    if (opts.status !== undefined && opts.status !== '') {
      query.andWhere('store.status = :status', { status: opts.status });
    }
    if (opts.search !== undefined && opts.search !== '') {
      const term = `%${opts.search}%`;
      query.andWhere('(store.name ILIKE :term OR store.slug ILIKE :term OR store.address ILIKE :term)', { term });
    }

    const [items, total] = await query.getManyAndCount();
    return { items, total };
  }

  async byId(id: number): Promise<Store | null> { return this.stores.findOne({ where: { id } }); }
  async require(id: number): Promise<Store> { const store = await this.byId(id); if (!store) throw new NotFoundException('Store not found.'); return store; }
  async create(dto: CreateStoreDto): Promise<Store> {
    const slug = await this.uniqueSlug(dto.slug ?? dto.name);
    return this.stores.save(this.stores.create({ ...dto, slug, status: dto.status ?? StoreStatus.Active, address: dto.address ?? null, phone: dto.phone ?? null, latitude: dto.latitude ?? null, longitude: dto.longitude ?? null, openingHours: dto.openingHours ?? null }));
  }
  async update(store: Store, dto: UpdateStoreDto): Promise<Store> {
    if (dto.slug && dto.slug !== store.slug) {
      const existing = await this.stores.findOne({ where: { slug: this.slugify(dto.slug) } });
      if (existing && existing.id !== store.id) throw new ConflictException('The store slug has already been taken.');
      store.slug = this.slugify(dto.slug);
    }
    Object.assign(store, { ...dto, slug: store.slug });
    return this.stores.save(store);
  }
  async addUser(storeId: number, userId: number): Promise<StoreUser> {
    await this.require(storeId);
    const existing = await this.storeUsers.findOne({ where: { storeId, userId } });
    return existing ?? this.storeUsers.save(this.storeUsers.create({ storeId, userId }));
  }
  async verifyUser(storeId: number, userId: number): Promise<void> {
    const membership = await this.storeUsers.findOne({ where: { storeId, userId } });
    if (!membership) throw new NotFoundException('Store membership not found.');
  }
  async userIds(storeId: number): Promise<number[]> { const rows = await this.storeUsers.find({ where: { storeId } }); return rows.map((row) => row.userId); }
  async forUser(userId: number, selected?: string): Promise<Store | null> {
    const memberships = await this.storeUsers.find({ where: { userId }, order: { storeId: 'ASC' } });
    const membership = selected ? memberships.find((row) => String(row.storeId) === selected) : memberships[0];
    return membership ? this.byId(membership.storeId) : null;
  }
  async storesForUser(userId: number): Promise<Store[]> {
    const memberships = await this.storeUsers.find({ where: { userId }, order: { storeId: 'ASC' } });
    const stores = await Promise.all(memberships.map((row) => this.byId(row.storeId)));
    return stores.filter((store): store is Store => store !== null);
  }
  async count(): Promise<number> { return this.stores.count(); }
  snapshot(store: Store): StoreSnapshot { return { id: store.id, name: store.name, slug: store.slug, status: store.status as StoreSnapshot['status'], latitude: store.latitude, longitude: store.longitude, address: store.address, phone: store.phone, openingHours: store.openingHours, deliveryZoneIds: store.deliveryZoneIds ?? [], categories: (store.categories ?? []).map((category) => ({ id: category.id, name: category.name, icon: category.icon, is_active: category.isActive })) }; }
  private async uniqueSlug(value: string): Promise<string> { const base = this.slugify(value); let slug = base; let suffix = 2; while (await this.stores.exists({ where: { slug } })) slug = `${base}-${suffix++}`; return slug; }
  private slugify(value: string): string { return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') || 'store'; }
}
