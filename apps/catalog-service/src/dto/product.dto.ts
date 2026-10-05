import { IsBoolean, IsInt, IsNumberString, IsOptional, IsString, Length, Min, Validate } from 'class-validator';
import { ProductImageValidator } from '../validation/product-image.validator';

export class CreateProductDto {
  @IsInt() @Min(1) storeId: number;
  @IsOptional() @IsInt() @Min(1) categoryId?: number;
  @IsString() @Length(1, 200) name: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() @Length(0, 120) sku?: string;
  @IsOptional() @Validate(ProductImageValidator) image?: string;
  @IsNumberString() price: string;
  @IsOptional() @IsInt() @Min(0) stock?: number;
  @IsOptional() @IsBoolean() isAvailable?: boolean;
}

export class UpdateProductDto {
  @IsOptional() @IsString() @Length(0, 120) sku?: string;
  @IsOptional() @Validate(ProductImageValidator) image?: string;
  @IsOptional() @IsInt() @Min(1) categoryId?: number;
  @IsOptional() @IsString() @Length(1, 200) name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsNumberString() price?: string;
  @IsOptional() @IsInt() @Min(0) stock?: number;
  @IsOptional() @IsBoolean() isAvailable?: boolean;
}
