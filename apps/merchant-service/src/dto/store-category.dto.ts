import { ArrayMaxSize, ArrayUnique, IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, Length, MaxLength, Min } from 'class-validator';
import { CATEGORY_ICON_KEYS } from './category-icons';

export class StoreCategoryDto {
  @IsOptional() @IsString() @IsIn(CATEGORY_ICON_KEYS) icon?: string;
  @IsString() @Length(1, 80) name: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional() @IsBoolean() is_active?: boolean;
}

export class StoreCategoryTagsDto {
  @IsArray() @ArrayMaxSize(50) @ArrayUnique() @IsInt({ each: true }) @Min(1, { each: true })
  category_ids: number[];
}
