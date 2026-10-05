import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateCategoryDto, UpdateCategoryDto } from '../dto/category.dto';
import { Category } from '../entities/category.entity';

@Injectable()
export class CategoryService {
  constructor(
    @InjectRepository(Category) private readonly categories: Repository<Category>,
  ) {}

  async listByStore(storeId: number): Promise<Category[]> {
    return this.categories.find({
      where: { storeId },
      order: { sortOrder: 'ASC', id: 'ASC' },
    });
  }

  async byId(id: number): Promise<Category | null> {
    return this.categories.findOne({ where: { id } });
  }

  async require(id: number): Promise<Category> {
    const category = await this.byId(id);
    if (!category) throw new NotFoundException('Category not found.');
    return category;
  }

  async create(dto: CreateCategoryDto): Promise<Category> {
    return this.categories.save(
      this.categories.create({
        storeId: dto.storeId,
        name: dto.name,
        description: dto.description ?? null,
        sortOrder: dto.sortOrder ?? 0,
      }),
    );
  }

  async update(category: Category, dto: UpdateCategoryDto): Promise<Category> {
    Object.assign(category, {
      name: dto.name ?? category.name,
      description: dto.description !== undefined ? dto.description : category.description,
      sortOrder: dto.sortOrder ?? category.sortOrder,
    });
    return this.categories.save(category);
  }

  async remove(category: Category): Promise<void> {
    await this.categories.remove(category);
  }

  async count(): Promise<number> {
    return this.categories.count();
  }
}
