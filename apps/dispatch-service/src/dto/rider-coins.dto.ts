import { IsString, IsUUID, Matches, MaxLength, IsOptional } from 'class-validator';

export class TopUpRiderCoinsDto {
  @IsString()
  @Matches(/^(?:0|[1-9]\d{0,7})(?:\.\d{1,2})?$/)
  amount: string;

  @IsUUID('4')
  request_id: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
