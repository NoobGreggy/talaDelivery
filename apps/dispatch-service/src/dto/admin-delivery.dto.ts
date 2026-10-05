import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Admin POST admin/deliveries/:id/assign. In the split, `rider_id` references
 * the dispatch `riders.id` (Laravel referenced users.id; identity resolution
 * happens only when shaping API resources).
 */
export class AssignDeliveryDto {
  @Type(() => Number)
  @IsInt()
  rider_id: number;
}

/** Admin POST admin/deliveries/:id/cancel (mirrors AdminDeliveryController::cancel). */
export class CancelDeliveryAdminDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string | null;
}