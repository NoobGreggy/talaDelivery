import { Component, inject, signal, computed, effect } from '@angular/core';
import { Router } from '@angular/router';
import { StoreProfileService } from '../../../core/services/store-profile.service';
import { StoreOrderService } from '../../../core/services/store-order.service';
import { StatCardComponent } from '../../../shared/components/stat-card/stat-card';
import { ButtonComponent } from '../../../shared/components/button/button';

@Component({
  selector: 'app-dashboard-page',
  standalone: true,
  imports: [StatCardComponent, ButtonComponent],
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

  protected readonly stats = computed(() => {
    const orders = this.orders();
    return {
      total: orders.length,
      pending: orders.filter((o) => o.status === 'PENDING').length,
      preparing: orders.filter((o) => o.status === 'PREPARING' || o.status === 'CONFIRMED').length,
      delivered: orders.filter((o) => o.status === 'DELIVERED').length,
      revenue: orders
        .filter((o) => o.status === 'DELIVERED')
        .reduce((sum, o) => sum + o.total, 0),
    };
  });

  protected readonly greeting = signal('');

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
}