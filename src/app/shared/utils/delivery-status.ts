import { Injectable, inject, signal, computed } from '@angular/core';

export const DELIVERY_STATUS_LABELS: Record<string, string> = {
  FINDING_RIDER: 'Finding Rider',
  RIDER_ASSIGNED: 'Rider Assigned',
  PICKED_UP: 'Picked Up',
  OUT_FOR_DELIVERY: 'Out for Delivery',
  DELIVERED: 'Delivered',
  FAILED: 'Failed',
  CANCELLED: 'Cancelled',
};

export const DELIVERY_STATUS_ORDER: string[] = [
  'FINDING_RIDER',
  'RIDER_ASSIGNED',
  'PICKED_UP',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
  'FAILED',
  'CANCELLED',
];

@Injectable({ providedIn: 'root' })
export class DeliveryStatusUtils {
  private label = signal<string>('');

  setStatus(status: string): void {
    this.label.set(DELIVERY_STATUS_LABELS[status] ?? status ?? '');
  }

  readonly labelText = computed(() => this.label());
}