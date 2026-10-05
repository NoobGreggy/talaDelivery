import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { OrderStatus, PaymentMethod } from '@taladelivery/contracts';

export class AdminOrderFiltersDto {
  @IsOptional() @IsIn(Object.values(OrderStatus)) status?: string;
  @IsOptional() @IsString() @MaxLength(160) search?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) store?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) customer?: number;
  @IsOptional() @IsIn(Object.values(PaymentMethod)) payment?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) per_page?: number;
}
