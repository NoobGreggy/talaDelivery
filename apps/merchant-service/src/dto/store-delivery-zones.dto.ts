import { ArrayMaxSize, ArrayUnique, IsArray, IsInt, Min } from 'class-validator';
export class StoreDeliveryZonesDto {
  @IsArray() @ArrayMaxSize(50) @ArrayUnique() @IsInt({ each: true }) @Min(1, { each: true })
  delivery_zone_ids: number[];
}
