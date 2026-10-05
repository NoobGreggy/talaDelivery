import { IsInt, IsLatitude, IsLongitude, IsString, Length, Min } from 'class-validator';

export class DeliveryQuoteDto {
  @IsInt() @Min(1) storeId: number;
  @IsLatitude() deliveryLatitude: string;
  @IsLongitude() deliveryLongitude: string;
  @IsString() @Length(1, 100) city: string;
  @IsString() @Length(1, 100) province: string;
}
