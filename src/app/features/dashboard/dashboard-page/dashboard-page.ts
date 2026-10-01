import { Component, inject, signal, computed, effect } from '@angular/core';
import { Router } from '@angular/router';
import { StoreProfileService } from '../../../core/services/store-profile.service';
import { StoreOrderService } from '../../../core/services/store-order.service';

@Component({
  selector: 'app-dashboard-page',
  standalone: true,
  templateUrl: './dashboard-page.html',
  styleUrl: './dashboard-page.css',
})
export class DashboardPageComponent {
  private profileService = inject(StoreProfileService);
  private orderService = inject(StoreOrderService);
  private router = inject(Router);

  protected readonly profile = this.profileService.profile;
  protected readonly profileLoading = this.profileService.loading;
  protected readonly orders = this.orderService.orders;
  protected readonly ordersLoading = this.orderService.loading;
  protected readonly pendingOrders = computed(() =>
    this.orders().filter((order) => order.status === 'PENDING'),
  );

  protected readonly stats = computed(() => {
    const orders = this.orders();
    return {
      total: orders.length,
      pending: this.pendingOrders().length,
      preparing: orders.filter((o) => o.status === 'PREPARING' || o.status === 'CONFIRMED').length,
      delivered: orders.filter((o) => o.status === 'DELIVERED').length,
      revenue: orders.filter((o) => o.status === 'DELIVERED').reduce((sum, o) => sum + o.total, 0),
    };
  });

  protected readonly greeting = signal('');
  private readonly pesoFormatter = new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  constructor() {
    this.profileService.load();
    this.orderService.load();
    const hour = new Date().getHours();
    if (hour < 12) {
      this.greeting.set('Good morning');
    } else if (hour < 18) {
      this.greeting.set('Good afternoon');
    } else {
      this.greeting.set('Good evening');
    }
    effect(() => {
      const p = this.profile();
      if (p) {
        document.title = `${p.name} | TalaDelivery Merchant`;
      }
    });
  }

  protected goToOrders(): void {
    this.router.navigate(['/orders']);
  }

  protected goToProducts(): void {
    this.router.navigate(['/products']);
  }

  protected formatMoney(value: unknown): string {
    const amount = typeof value === 'number' ? value : Number(value);
    return this.pesoFormatter.format(Number.isFinite(amount) ? amount : 0);
  }

  protected formatStatus(status: string | null | undefined): string {
    if (!status) return 'Inactive';
    return status
      .toLowerCase()
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }
}
