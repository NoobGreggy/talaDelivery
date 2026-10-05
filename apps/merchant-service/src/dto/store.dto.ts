import { IsIn, IsInt, IsObject, IsOptional, IsString, Length, Max, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { StoreStatus } from '@taladelivery/contracts';

class OpeningHoursDayDto {
  @IsString() open: string;
  @IsString() close: string;
  @IsOptional() @IsIn([true, false]) isClosed?: boolean;
}

export class CreateStoreDto {
  @IsString() @Length(1, 160) name: string;
  @IsOptional() @IsString() @Length(1, 180) slug?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() @Length(1, 40) phone?: string;
  @IsOptional() @IsString() latitude?: string;
  @IsOptional() @IsString() longitude?: string;
  @IsOptional() @IsIn(Object.values(StoreStatus)) status?: string;
  @IsOptional() @IsObject() @ValidateNested() @Type(() => OpeningHoursDayDto) openingHours?: Record<string, OpeningHoursDayDto>;
}

export class UpdateStoreDto extends CreateStoreDto {}

export class StoreUserDto {
  @IsInt() @Min(1) storeId: number;
  @IsInt() @Min(1) userId: number;
}
