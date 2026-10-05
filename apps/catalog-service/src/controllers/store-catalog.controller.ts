import { BadRequestException, Body, Controller, Delete, Get, Headers, NotFoundException, Param, ParseIntPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import { AppKeyGuard, CurrentUser, JwtAuthGuard, Roles, RolesGuard, JwtPayload } from '@taladelivery/auth';
import { Message, ServiceClientFactory } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, Length, Min, Validate } from 'class-validator';
import { ProductImageValidator } from '../validation/product-image.validator';
import { ProductService } from '../services/product.service';
import { CategoryService } from '../services/category.service';
import { Product } from '../entities/product.entity';
import { Category } from '../entities/category.entity';

export class StoreProductDto {
  @IsOptional() @IsString() @Length(1, 200) name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() @Length(0, 120) sku?: string;
  @IsOptional() @Validate(ProductImageValidator) image?: string;
  @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) price?: number;
  @IsOptional() @IsInt() @Min(0) stock?: number;
  @IsOptional() @IsInt() @Min(1) category_id?: number | null;
  @IsOptional() @IsBoolean() is_available?: boolean;
}
export class StoreCategoryDto {
  @IsString() @Length(1, 160) name: string;
  @IsOptional() @IsString() description?: string;
}

@Controller('store')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.StoreAdmin)
export class StoreCatalogController {
  constructor(private readonly products: ProductService, private readonly categories: CategoryService,
    private readonly factory: ServiceClientFactory) {}

  async storeId(userId: number, selected?: string): Promise<number> {
    const stores = await this.factory.create('MERCHANT_SERVICE_URL').get<Array<{ id: number }>>(`/internal/stores/by-user/${userId}`);
    const store = selected ? stores.find((store) => String(store.id) === selected) : stores[0];
    if (!store) throw new NotFoundException('Store membership not found.');
    return store.id;
  }
  private productJson(product: Product) {
    return { id: product.id, store_id: product.storeId, category_id: product.categoryId,
      name: product.name, description: product.description, sku: product.sku, image: product.image,
      price: Number(product.price), stock: product.stock,
      is_available: product.isAvailable, created_at: product.createdAt.toISOString() };
  }
  private categoryJson(category: Category) {
    return { id: category.id, store_id: category.storeId, name: category.name, description: category.description,
      status: 'ACTIVE', created_at: category.createdAt.toISOString() };
  }
  private async ownedProduct(userId: number, selected: string, id: number) {
    const storeId = await this.storeId(userId, selected);
    const product = await this.products.require(id);
    if (product.storeId !== storeId) throw new NotFoundException('Product not found.');
    return product;
  }
  private async ownedCategory(userId: number, selected: string, id: number) {
    const storeId = await this.storeId(userId, selected);
    const category = await this.categories.require(id);
    if (category.storeId !== storeId) throw new NotFoundException('Category not found.');
    return category;
  }
  private async validateCategory(storeId: number, categoryId?: number | null) {
    if (categoryId == null) return;
    const category = await this.categories.require(categoryId);
    if (category.storeId !== storeId) throw new NotFoundException('Category not found.');
  }

  @Get('products') @Message('Store products retrieved.')
  async listProducts(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string,
    @Query('search') search?: string, @Query('category_id') category?: string) {
    const products = await this.products.listByStore(await this.storeId(user.sub, selected));
    return { data: products.filter((product) => (!category || String(product.categoryId) === category)
      && (!search || product.name.toLowerCase().includes(search.toLowerCase()))).map((product) => this.productJson(product)) };
  }
  @Get('products/:id') @Message('Product retrieved.')
  async showProduct(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    return this.productJson(await this.ownedProduct(user.sub, selected, id));
  }
  @Post('products') @Message('Product created.')
  async createProduct(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Body() dto: StoreProductDto) {
    const storeId = await this.storeId(user.sub, selected);
    if (!dto.name || dto.price == null) throw new BadRequestException('Product name and price are required.');
    await this.validateCategory(storeId, dto.category_id);
    return this.productJson(await this.products.create({ storeId, name: dto.name, description: dto.description,
      sku: dto.sku, image: dto.image, price: dto.price.toFixed(2), stock: dto.stock,
      categoryId: dto.category_id ?? undefined, isAvailable: dto.is_available }));
  }
  @Put('products/:id') @Message('Product updated.')
  async updateProduct(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number, @Body() dto: StoreProductDto) {
    const product = await this.ownedProduct(user.sub, selected, id);
    await this.validateCategory(product.storeId, dto.category_id);
    return this.productJson(await this.products.update(product, { name: dto.name, description: dto.description, sku: dto.sku, image: dto.image,
      price: dto.price?.toFixed(2), stock: dto.stock, categoryId: dto.category_id as number | undefined, isAvailable: dto.is_available }));
  }
  @Delete('products/:id') @Message('Product deleted.')
  async deleteProduct(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    await this.products.remove(await this.ownedProduct(user.sub, selected, id)); return null;
  }
  @Get('categories') @Message('Categories retrieved.')
  async listCategories(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string) {
    return { data: (await this.categories.listByStore(await this.storeId(user.sub, selected))).map((category) => this.categoryJson(category)) };
  }
  @Get('categories/:id') @Message('Category retrieved.')
  async showCategory(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    return this.categoryJson(await this.ownedCategory(user.sub, selected, id));
  }
  @Post('categories') @Message('Category created.')
  async createCategory(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Body() dto: StoreCategoryDto) {
    return this.categoryJson(await this.categories.create({ ...dto, storeId: await this.storeId(user.sub, selected) }));
  }
  @Put('categories/:id') @Message('Category updated.')
  async updateCategory(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number, @Body() dto: StoreCategoryDto) {
    return this.categoryJson(await this.categories.update(await this.ownedCategory(user.sub, selected, id), dto));
  }
  @Delete('categories/:id') @Message('Category deleted.')
  async deleteCategory(@CurrentUser() user: JwtPayload, @Headers('x-store-id') selected: string, @Param('id', ParseIntPipe) id: number) {
    await this.categories.remove(await this.ownedCategory(user.sub, selected, id)); return null;
  }
}
