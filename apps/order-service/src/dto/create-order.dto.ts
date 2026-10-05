import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Length,
  Min,
  ValidateNested,
} from 'class-validator';

class OrderItemDto {
  @IsInt() @Min(1) productId: number;
  @IsInt() @Min(1) quantity: number;
}

export class CreateOrderDto {
  @IsOptional() @IsString() @Length(0, 1000) notes?: string;
  @IsInt() @Min(1) storeId: number;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items: OrderItemDto[];

  @IsString() @Length(1, 500) deliveryAddress: string;

  @IsLatitude() deliveryLatitude: string;

  @IsLongitude() deliveryLongitude: string;

  @IsOptional() @IsString() @Length(1, 500) pickupAddress?: string;

  @IsOptional() @IsLatitude() pickupLatitude?: string;

  @IsOptional() @IsLongitude() pickupLongitude?: string;

  @IsOptional() @IsString() @Length(1, 500) customerName?: string;

  @IsOptional() @IsString() @Length(1, 40) customerPhone?: string;

  @IsOptional() @IsString() @Length(1, 100) city?: string;

  @IsOptional() @IsString() @Length(1, 100) province?: string;
}
