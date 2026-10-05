import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { CommissionType } from '@taladelivery/contracts';

/**
 * Internal POST /internal/deliveries — creates the UNASSIGNED delivery row
 * after order-service has inserted the order and priced it.
 */
export class CreateDeliveryDto {
  @IsOptional()
  @IsInt()
  deliveryZoneId?: number;

  @Type(() => Number)
  @IsInt()
  orderId: number;

  @Type(() => Number)
  @IsInt()
  storeId: number;

  @IsOptional()
  @IsString()
  pickupAddress?: string | null;

  @IsOptional()
  @IsString()
  pickupLatitude?: string | null;

  @IsOptional()
  @IsString()
  pickupLongitude?: string | null;

  @IsOptional()
  @IsString()
  deliveryAddress?: string | null;

  @IsOptional()
  @IsString()
  deliveryLatitude?: string | null;

  @IsOptional()
  @IsString()
  deliveryLongitude?: string | null;

  @IsOptional()
  @IsString()
  distanceKm?: string | null;

  @IsOptional()
  @IsString()
  deliveryFee?: string | null;

  @IsOptional()
  @IsString()
  riderCommission?: string | null;

  @IsOptional()
  @IsIn([CommissionType.Fixed, CommissionType.Percentage])
  commissionType?: string | null;

  @IsOptional()
  @IsString()
  commissionValue?: string | null;
}

/** Internal POST /internal/deliveries/:id/cancel. */
export class CancelDeliveryInternalDto {
  @IsString()
  cancelledBy: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string | null;
}

/** Admin POST admin/deliveries/:id/cancel. */
export class CancelDeliveryAdminDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string | null;
}
