import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  AppKeyGuard,
  CurrentUser,
  JwtAuthGuard,
  Roles,
  RolesGuard,
  type JwtPayload,
} from '@taladelivery/auth';
import { Message, PaginatedResult, requestContext, resolvePagination } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { ServiceClient, ServiceClientFactory } from '@taladelivery/common';
import { CreateProductDto, UpdateProductDto } from '../dto/product.dto';
import { ProductService } from '../services/product.service';

@Controller('merchant/products')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.StoreAdmin)
export class MerchantProductsController {
  constructor(
    private readonly products: ProductService,
    private readonly factory: ServiceClientFactory,
  ) {}

  private get merchant(): ServiceClient {
    return this.factory.create('MERCHANT_SERVICE_URL');
  }

  @Get()
  @Message('Products retrieved.')
  async index(
    @CurrentUser() user: JwtPayload,
    @Query('page') page?: number,
    @Query('per_page') perPage?: number,
  ) {
    const storeId = await this.resolveStoreId(user.sub);
    const { page: p, perPage: pp } = resolvePagination({ page, perPage });
    const all = await this.products.listByStore(storeId);
    const total = all.length;
    const items = all.slice((p - 1) * pp, p * pp);
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

  @Get(':id')
  @Message('Product retrieved.')
  async show(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const product = await this.products.require(id);
    const storeId = await this.resolveStoreId(user.sub);
    if (product.storeId !== storeId) throw new NotFoundException('Product not found.');
    return this.products.toJson(product);
  }

  @Post()
  @Message('Product created.')
  async create(@CurrentUser() user: JwtPayload, @Body() dto: CreateProductDto) {
    const storeId = await this.resolveStoreId(user.sub);
    const product = await this.products.create({ ...dto, storeId });
    return this.products.toJson(product);
  }

  @Put(':id')
  @Message('Product updated.')
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateProductDto,
  ) {
    const product = await this.products.require(id);
    const storeId = await this.resolveStoreId(user.sub);
    if (product.storeId !== storeId) throw new NotFoundException('Product not found.');
    const updated = await this.products.update(product, dto);
    return this.products.toJson(updated);
  }

  @Delete(':id')
  @Message('Product deleted.')
  async destroy(@CurrentUser() user: JwtPayload, @Param('id', ParseIntPipe) id: number) {
    const product = await this.products.require(id);
    const storeId = await this.resolveStoreId(user.sub);
    if (product.storeId !== storeId) throw new NotFoundException('Product not found.');
    await this.products.remove(product);
    return null;
  }

  private async resolveStoreId(userId: number): Promise<number> {
    const stores = await this.merchant.get<Array<{ id: number }>>(
      `/internal/stores/by-user/${userId}`,
    );
    const owned = stores?.[0];
    if (!owned) throw new NotFoundException('No store assigned to this user.');
    return owned.id;
  }
}
