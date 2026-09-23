import { Component, computed, input } from '@angular/core';

@Component({
  selector: 'app-status-badge',
  standalone: true,
  templateUrl: './status-badge.html',
  styleUrl: './status-badge.css',
})
export class StatusBadgeComponent {
  status = input.required<string>();

  protected colorClasses = computed(() => {
    const emerald = [
      'DELIVERED',
      'ONLINE',
      'ACTIVE',
    ];
    const blue = [
      'RIDER_ASSIGNED',
      'PICKED_UP',
      'OUT_FOR_DELIVERY',
      'CONFIRMED',
      'PREPARING',
    ];
    const amber = [
      'FINDING_RIDER',
      'PENDING',
      'READY_FOR_PICKUP',
    ];
    const red = ['FAILED', 'CANCELLED', 'OFFLINE', 'SUSPENDED'];

    const status = this.status().toUpperCase();

    if (emerald.includes(status)) {
      return 'bg-emerald-100 text-emerald-700';
    }
    if (blue.includes(status)) {
      return 'bg-blue-100 text-blue-700';
    }
    if (amber.includes(status)) {
      return 'bg-amber-100 text-amber-700';
    }
    if (red.includes(status)) {
      return 'bg-red-100 text-red-700';
    }
    return 'bg-slate-100 text-slate-700';
  });
}