import {
  IsIn,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/** Admin GET admin/place-boundaries (query params; Laravel SearchPlaceBoundaryRequest). */
export class SearchPlaceBoundaryDto {
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  query: string;

  @IsIn(['city', 'province'])
  type: string;
}