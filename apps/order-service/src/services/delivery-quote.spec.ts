import { validate } from 'class-validator';
import { DomainError } from '@taladelivery/common';
import { OrderService } from './order.service';
import { DeliveryQuoteDto } from '../dto/delivery-quote.dto';

const dto: DeliveryQuoteDto = { storeId: 1, deliveryLatitude: '14.6', deliveryLongitude: '121.03', city: 'Makati City', province: 'Metro Manila' };
function harness(status = 'ACTIVE') {
  const merchant = { get: jest.fn().mockResolvedValue({ status, latitude: '14.5547', longitude: '121.0244', deliveryZoneIds: [1] }) };
  const dispatch = { post: jest.fn().mockResolvedValue({ deliveryFee: '59.00', distanceKm: '4.00', billableDistanceKm: '4.00', distanceMethod: 'STRAIGHT_LINE',
    zone: { id: 1, name: 'Makati Zone', talaCoinsPercent: '10.00' }, riderCommission: '20.00' }) };
  const factory = { create: jest.fn((name: string) => name === 'MERCHANT_SERVICE_URL' ? merchant : dispatch) };
  const service: OrderService = Object.assign(Object.create(OrderService.prototype), { factory });
  return { service, merchant, dispatch, factory };
}
describe('Customer delivery quotes', () => {
  it('uses the store pickup location and shared admin-zone pricing, without any writes', async () => {
    const h = harness();
    expect(await h.service.quoteDelivery(dto)).toEqual({ deliveryFee: '59.00', distanceKm: '4.00', billableDistanceKm: '4.00',
      distanceMethod: 'STRAIGHT_LINE', zone: { id: 1, name: 'Makati Zone' } });
    expect(h.merchant.get).toHaveBeenCalledWith('/internal/stores/1');
    expect(h.dispatch.post).toHaveBeenCalledTimes(1);
    expect(h.dispatch.post).toHaveBeenCalledWith('/internal/pricing/calculate', {
      pickupLatitude: '14.5547', pickupLongitude: '121.0244', deliveryLatitude: '14.6', deliveryLongitude: '121.03',
      city: 'Makati City', province: 'Metro Manila',
      allowedZoneIds: [1],
    });
    expect(h.factory.create.mock.calls.map(([name]) => name)).toEqual(['MERCHANT_SERVICE_URL', 'DISPATCH_SERVICE_URL']);
  });
  it('rejects inactive stores before calculating', async () => {
    const h = harness('SUSPENDED');
    await expect(h.service.quoteDelivery(dto)).rejects.toThrow('not accepting orders');
    expect(h.dispatch.post).not.toHaveBeenCalled();
  });
  it('surfaces unavailable delivery zones instead of inventing a free fee', async () => {
    const h = harness();
    h.dispatch.post.mockRejectedValue(new DomainError('Delivery is not available in the selected city.'));
    await expect(h.service.quoteDelivery(dto)).rejects.toThrow('Delivery is not available');
  });
  it('does not let pickup overrides change the fee used for creation', async () => {
    const h = harness();
    await (h.service as any).deliveryPricing({ latitude: '14.5547', longitude: '121.0244', deliveryZoneIds: [1] }, { ...dto, pickupLatitude: '14.6', pickupLongitude: '121.03' });
    expect(h.dispatch.post.mock.calls[0][1].pickupLatitude).toBe('14.5547');
  });
  it('validates coordinates and requires city and province', async () => {
    expect(await validate(Object.assign(new DeliveryQuoteDto(), dto))).toEqual([]);
    const errors = await validate(Object.assign(new DeliveryQuoteDto(), { ...dto, deliveryLatitude: '91', city: '', province: '' }));
    expect(errors.map((error) => error.property)).toEqual(expect.arrayContaining(['deliveryLatitude', 'city', 'province']));
  });
  it('rejects unassigned stores without calling dispatch', async () => {
    const h = harness();
    h.merchant.get.mockResolvedValue({ status: 'ACTIVE', latitude: '14.5547', longitude: '121.0244', deliveryZoneIds: [] });
    await expect(h.service.quoteDelivery(dto)).rejects.toThrow('no assigned delivery zones');
    expect(h.dispatch.post).not.toHaveBeenCalled();
  });
});
