import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  AppKeyGuard,
  JwtAuthGuard,
  Roles,
  RolesGuard,
} from '@taladelivery/auth';
import { Message } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { SearchPlaceBoundaryDto } from '../../dto/place-boundary.dto';
import { PlaceBoundarySearchService } from '../../services/place-boundary-search.service';

/**
 * Admin GET admin/place-boundaries (mirrors Laravel AdminPlaceBoundaryController).
 * Nominatim-backed city/province boundary search with Redis caching. Unavailable
 * upstream becomes a 503 (the exception filter keeps the Laravel message).
 */
@Controller('admin/place-boundaries')
@UseGuards(AppKeyGuard, JwtAuthGuard, RolesGuard)
@Roles(Role.PlatformAdmin)
export class AdminPlaceBoundaryController {
  constructor(private readonly boundaries: PlaceBoundarySearchService) {}

  @Get()
  @Message('Place boundaries retrieved.')
  async search(@Query() dto: SearchPlaceBoundaryDto) {
    return this.boundaries.search(
      dto.query.replace(/\s+/g, ' ').trim(),
      dto.type,
    );
  }
}