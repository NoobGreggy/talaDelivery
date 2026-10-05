import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DomainError } from '@taladelivery/common';
import { DataSource, In, Repository } from 'typeorm';
import { StoreCategory } from '../entities/store-category.entity';
import { Store } from '../entities/store.entity';
import { StoreCategoryDto } from '../dto/store-category.dto';

@Injectable()
export class StoreCategoryService {
  constructor(private readonly dataSource: DataSource,
    @InjectRepository(StoreCategory) private readonly categories: Repository<StoreCategory>) {}

  async list(activeOnly = false) {
    const query = this.categories.createQueryBuilder('category')
      .loadRelationCountAndMap('category.storeCount', 'category.stores')
      .orderBy('category.name', 'ASC').addOrderBy('category.id', 'ASC');
    if (activeOnly) query.where('category.is_active = true');
    return (await query.getMany()).map((category) => this.snapshot(category));
  }

  async save(dto: StoreCategoryDto, id?: number) {
    const name = dto.name.replace(/\s+/g, ' ').trim();
    if (!name) throw new DomainError('Category name is required.');
    const category = id == null ? this.categories.create() : await this.categories.findOneBy({ id });
    if (!category) throw new NotFoundException('Category not found.');
    category.name = name;
    category.normalizedName = name.toLowerCase();
    category.icon = dto.icon ?? category.icon ?? 'restaurant_rounded';
    category.description = dto.description?.trim() || null;
    category.isActive = dto.is_active ?? category.isActive ?? true;
    try { await this.categories.save(category); }
    catch (error) {
      if ((error as { driverError?: { code?: string } }).driverError?.code === '23505') {
        throw new ConflictException('A store category with this name already exists.');
      }
      throw error;
    }
    return this.snapshot(category);
  }

  async tagStore(storeId: number, categoryIds: number[]): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const store = await manager.getRepository(Store).createQueryBuilder('store')
        .setLock('pessimistic_write').where('store.id = :id', { id: storeId }).getOne();
      if (!store) throw new NotFoundException('Store not found.');
      const existing: StoreCategory[] = await manager.createQueryBuilder().relation(Store, 'categories').of(storeId).loadMany();
      const categories = categoryIds.length ? await manager.getRepository(StoreCategory).findBy({ id: In(categoryIds) }) : [];
      if (categories.length !== categoryIds.length) throw new DomainError('One or more selected categories no longer exist.');
      const oldIds = existing.map((category) => category.id);
      if (categories.some((category) => !category.isActive && !oldIds.includes(category.id))) {
        throw new DomainError('Inactive categories cannot be added to a store.');
      }
      const added = categoryIds.filter((id) => !oldIds.includes(id));
      const removed = oldIds.filter((id) => !categoryIds.includes(id));
      const relation = manager.createQueryBuilder().relation(Store, 'categories').of(storeId);
      if (removed.length) await relation.remove(removed);
      if (added.length) await relation.add(added);
    });
  }

  snapshot(category: StoreCategory) {
    return { id: category.id, name: category.name, icon: category.icon, description: category.description,
      is_active: category.isActive, store_count: category.storeCount ?? 0,
      created_at: category.createdAt.toISOString(), updated_at: category.updatedAt.toISOString() };
  }
}
