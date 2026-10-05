import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AppKeyGuard } from '@taladelivery/auth';
import { Message, PaginatedResult, resolvePagination, requestContext } from '@taladelivery/common';
import { CategoryService } from '../services/category.service';
import { ProductService } from '../services/product.service';

@Controller()
@UseGuards(AppKeyGuard)
export class CatalogController {
  constructor(
    private readonly categories: CategoryService,
    private readonly products: ProductService,
  ) {}

  @Get('stores/:store/categories')
  @Message('Categories retrieved.')
  async listCategories(@Param('store', ParseIntPipe) storeId: number) {
    const categories = await this.categories.listByStore(storeId);
    return categories.map((category) => ({
      id: category.id,
      storeId: category.storeId,
      name: category.name,
      description: category.description,
      sortOrder: category.sortOrder,
    }));
  }

  @Get('stores/:store/products')
  @Message('Products retrieved.')
  async listStoreProducts(
    @Param('store', ParseIntPipe) storeId: number,
    @Query('category') categoryId?: number,
  ) {
    const products = await this.products.listByStore(storeId, categoryId);
    return products.map((product) => this.products.toJson(product));
  }

  @Get('products')
  @Message('Products retrieved.')
  async listProducts(
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
    @Query('store_id', new ParseIntPipe({ optional: true })) storeId?: number,
    @Query('category_id', new ParseIntPipe({ optional: true })) categoryId?: number,
    @Query('search') search?: string,
  ) {
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const { items, total } = await this.products.listAll(p, pp, { storeId, categoryId, search });
    return new PaginatedResult(
      items.map((product) => this.products.toJson(product)),
      {
        currentPage: p,
        lastPage: Math.max(1, Math.ceil(total / pp)),
        perPage: pp,
        total,
        path: requestContext().path,
      },
    );
  }

  @Get('products/:id')
  @Message('Product retrieved.')
  async getProduct(@Param('id', ParseIntPipe) id: number) {
    const product = await this.products.require(id);
    return this.products.toJson(product);
  }
}
