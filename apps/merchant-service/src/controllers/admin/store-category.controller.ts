import { Body, Controller, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { AppKeyGuard, JwtAuthGuard, Roles, RolesGuard } from '@taladelivery/auth';
import { Message } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { StoreCategoryService } from '../../services/store-category.service';
import { StoreCategoryDto } from '../../dto/store-category.dto';
import { CATEGORY_ICONS } from '../../dto/category-icons';

@Controller('admin/store-categories')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminStoreCategoryController {
  @Get('icons') @Message('Category icons retrieved.')
  icons() { return CATEGORY_ICONS; }
  constructor(private readonly categories: StoreCategoryService) {}
  @Get() @Message('Store categories retrieved.')
  list() { return this.categories.list(); }
  @Post() @Message('Store category created.')
  create(@Body() dto: StoreCategoryDto) { return this.categories.save(dto); }
  @Put(':id') @Message('Store category updated.')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: StoreCategoryDto) { return this.categories.save(dto, id); }
}

@Controller('store-categories')
@UseGuards(AppKeyGuard)
export class StoreCategoryController {
  constructor(private readonly categories: StoreCategoryService) {}
  @Get() @Message('Store categories retrieved.')
  list() { return this.categories.list(true); }
}
