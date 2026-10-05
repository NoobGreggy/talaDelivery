import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsWhere, ILike, Repository } from 'typeorm';
import { CreateProductDto, UpdateProductDto } from '../dto/product.dto';
import { Product } from '../entities/product.entity';
import { moneyString } from '../common/format.util';

@Injectable()
export class ProductService {
  constructor(
    @InjectRepository(Product) private readonly products: Repository<Product>,
  ) {}

  async listByStore(storeId: number, categoryId?: number): Promise<Product[]> {
    const where: Record<string, unknown> = { storeId, isAvailable: true };
    if (categoryId) where.categoryId = categoryId;
    return this.products.find({ where, order: { id: 'ASC' } });
  }

  async listAll(page: number, perPage: number, filters: { storeId?: number; categoryId?: number; search?: string } = {}): Promise<{ items: Product[]; total: number }> {
    const where: FindOptionsWhere<Product> = { isAvailable: true };
    if (filters.storeId) where.storeId = filters.storeId;
    if (filters.categoryId) where.categoryId = filters.categoryId;
    if (filters.search?.trim()) where.name = ILike(`%${filters.search.trim().replace(/[\\%_]/g, '\\$&')}%`);
    const [items, total] = await this.products.findAndCount({
      where,
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { items, total };
  }

  async byId(id: number): Promise<Product | null> {
    return this.products.findOne({ where: { id } });
  }

  async require(id: number): Promise<Product> {
    const product = await this.byId(id);
    if (!product) throw new NotFoundException('Product not found.');
    return product;
  }

  async create(dto: CreateProductDto): Promise<Product> {
    return this.products.save(
      this.products.create({
        storeId: dto.storeId,
        categoryId: dto.categoryId ?? null,
        name: dto.name,
        description: dto.description ?? null,
        price: dto.price,
        stock: dto.stock ?? 0,
        isAvailable: dto.isAvailable ?? true,
        sku: dto.sku ?? null,
        image: dto.image ?? null,
      }),
    );
  }

  async update(product: Product, dto: UpdateProductDto): Promise<Product> {
    Object.assign(product, {
      sku: dto.sku !== undefined ? dto.sku : product.sku,
      image: dto.image !== undefined ? dto.image : product.image,
      categoryId: dto.categoryId !== undefined ? dto.categoryId : product.categoryId,
      name: dto.name ?? product.name,
      description: dto.description !== undefined ? dto.description : product.description,
      price: dto.price ?? product.price,
      stock: dto.stock ?? product.stock,
      isAvailable: dto.isAvailable ?? product.isAvailable,
    });
    return this.products.save(product);
  }

  async remove(product: Product): Promise<void> {
    await this.products.remove(product);
  }

  async count(): Promise<number> {
    return this.products.count();
  }

  toJson(product: Product): Record<string, unknown> {
    return {
      id: product.id,
      storeId: product.storeId,
      categoryId: product.categoryId,
      name: product.name,
      description: product.description,
      image: product.image,
      sku: product.sku,
      price: moneyString(product.price),
      stock: product.stock,
      isAvailable: product.isAvailable,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    };
  }
}
