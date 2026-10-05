import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { DomainError, requestContext } from '@taladelivery/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Product } from '../../entities/product.entity';
import { Category } from '../../entities/category.entity';
import { ProductService } from '../../services/product.service';
import { CategoryService } from '../../services/category.service';
import { moneyString } from '../../common/format.util';

@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class CatalogInternalController {
  constructor(
    private readonly dataSource: DataSource,
    private readonly products: ProductService,
    private readonly categories: CategoryService,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
    @InjectRepository(Category) private readonly categoryRepo: Repository<Category>,
  ) {}

  @Post('orders/validate')
  async validateOrder(@Body() body: { storeId: number; items: Array<{ productId: number; quantity: number }> }) {
    const { storeId, items } = body;
    if (!storeId || !Array.isArray(items) || items.length === 0) {
      throw new DomainError('A valid store and items are required.');
    }

    return this.dataSource.transaction(async (manager) => {
      const productRepo = manager.getRepository(Product);
      const results: Array<Record<string, unknown>> = [];
      let subtotalMinor = 0;

      for (const item of items) {
        const product = await productRepo
          .createQueryBuilder('product')
          .setLock('pessimistic_write')
          .where('product.id = :id', { id: item.productId })
          .getOne();

        if (!product) throw new NotFoundException('Product not found.');
        if (product.storeId !== storeId) throw new NotFoundException('Product not found.');
        if (!product.isAvailable) throw new DomainError(`${product.name} is currently unavailable.`);
        if (product.stock < item.quantity) throw new DomainError(`Insufficient stock for ${product.name}.`);

        product.stock -= item.quantity;
        await productRepo.save(product);

        const unitPriceMinor = Math.round(Number.parseFloat(product.price) * 100);
        const lineSubtotalMinor = unitPriceMinor * item.quantity;
        subtotalMinor += lineSubtotalMinor;

        results.push({
          productId: product.id,
          name: product.name,
          quantity: item.quantity,
          unitPrice: moneyString(unitPriceMinor / 100),
          subtotal: moneyString(lineSubtotalMinor / 100),
        });
      }

      return {
        items: results,
        subtotal: moneyString(subtotalMinor / 100),
      };
    });
  }

  @Get('admin/totals')
  async totals() {
    const [products, categories] = await Promise.all([
      this.products.count(),
      this.categories.count(),
    ]);
    return { products, categories };
  }
}
