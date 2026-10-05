import { IsOptional, IsString, MaxLength } from 'class-validator';

/** Admin POST /api/v1/admin/payments/:id/refund. */
export class RefundPaymentDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string | null;
}