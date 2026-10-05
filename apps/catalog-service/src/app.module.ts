import { Module } from '@nestjs/common';
import { StoreCatalogController } from './controllers/store-catalog.controller';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '@taladelivery/auth';
import { createEnvValidator, HealthController, ServiceClientFactory } from '@taladelivery/common';
import { CATALOG_DB_NAME, CatalogEnvironmentVariables } from './config/env';
import { Category } from './entities/category.entity';
import { Product } from './entities/product.entity';
import { CatalogController } from './controllers/catalog.controller';
import { MerchantProductsController } from './controllers/merchant-products.controller';
import { CatalogInternalController } from './controllers/internal/internal.controller';
import { CategoryService } from './services/category.service';
import { ProductService } from './services/product.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: createEnvValidator(CatalogEnvironmentVariables),
      envFilePath: ['.env.local', '.env'],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres' as const,
        host: config.get<string>('POSTGRES_HOST', 'localhost'),
        port: config.get<number>('POSTGRES_PORT', 5432),
        username: config.get<string>('POSTGRES_USER', 'tala'),
        password: config.get<string>('POSTGRES_PASSWORD', ''),
        database: config.get<string>('POSTGRES_DB_NAME') ?? CATALOG_DB_NAME,
        ssl: config.get<string>('POSTGRES_SSL') === 'true' ? { rejectUnauthorized: false } : false,
        autoLoadEntities: true,
        synchronize: config.get<string>('NODE_ENV') !== 'production',
        logging: false,
      }),
    }),
    TypeOrmModule.forFeature([Category, Product]),
    AuthModule,
  ],
  controllers: [HealthController, CatalogController, StoreCatalogController, MerchantProductsController, CatalogInternalController],
  providers: [CategoryService, ProductService, ServiceClientFactory],
})
export class AppModule {}
