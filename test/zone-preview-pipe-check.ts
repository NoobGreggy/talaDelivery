/**
 * Proves the PreviewZonePricingDto whitelist fix: the global pipe runs with
 * `whitelist: true`, which strips any property with no validation decorator.
 * `@Type(() => ZonePricingInputDto)` alone left `zone` undefined -> 500.
 * Run without touching the running services.
 */
import 'reflect-metadata';
import { laravelValidationPipe } from '@taladelivery/common/validation';
import { PreviewZonePricingDto } from '../apps/dispatch-service/src/dto/delivery-zone.dto';

const payload = {
  zone: {
    name: 'Makati Zone',
    province: 'Metro Manila',
    base_fee: '49.00',
    included_km: '5.00',
    extra_fee_per_km: '10.00',
    distance_rounding_km: '0.50',
  },
  pickup_latitude: '14.5547',
  pickup_longitude: '121.0244',
  delivery_latitude: '14.5570',
  delivery_longitude: '121.0270',
  distance_method: 'STRAIGHT_LINE',
};

async function main(): Promise<void> {
  const pipe = laravelValidationPipe();
  const dto = await pipe.transform(payload, { type: 'body', metatype: PreviewZonePricingDto });

  console.log('dto.zone is defined      :', dto.zone !== undefined);
  console.log('dto.zone is a class inst :', dto.zone?.constructor?.name);
  console.log('dto.zone.base_fee        :', JSON.stringify(dto.zone?.base_fee));
  console.log('dto.zone.included_km     :', JSON.stringify(dto.zone?.included_km));
  console.log('delivery_latitude kept   :', JSON.stringify(dto.delivery_latitude));

  if (dto.zone === undefined) {
    console.error('\nFAIL: zone was stripped by the whitelist.');
    process.exit(1);
  }
  console.log('\nPASS: nested zone survives validation.');
}

void main();
