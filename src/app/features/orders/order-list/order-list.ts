import { Component, inject, signal, computed, DestroyRef } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { StoreOrderService } from '../../../core/services/store-order.service';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { PaginationComponent } from '../../../shared/components/pagination/pagination';
import { Order } from '../../../core/models';

@Component({
  selector: 'app-order-list',
  standalone: true,
  imports: [
    DatePipe,
    CurrencyPipe,
    SearchInputComponent,
    StatusBadgeComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    PaginationComponent,
  ],
  templateUrl: './order-list.html',
  styleUrl: './order-list.css',
})
export class OrderListComponent {
  private orderService = inject(StoreOrderService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private destroyRef = inject(DestroyRef);

  protected readonly orders = this.orderService.orders;
  protected readonly loading = this.orderService.loading;
  protected readonly error = this.orderService.error;
  protected readonly currentPage = this.orderService.currentPage;
  protected readonly lastPage = this.orderService.lastPage;

  protected readonly searchTerm = signal('');
  protected readonly statusFilter = signal('all');

  protected readonly statusFilters: { value: string; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'PENDING', label: 'Pending' },
    { value: 'CONFIRMED', label: 'Confirmed' },
    { value: 'PREPARING', label: 'Preparing' },
    { value: 'READY_FOR_PICKUP', label: 'Ready' },
    { value: 'RIDER_ASSIGNED', label: 'Assigned' },
    { value: 'OUT_FOR_DELIVERY', label: 'Out for Delivery' },
    { value: 'DELIVERED', label: 'Delivered' },
    { value: 'CANCELLED', label: 'Cancelled' },
  ];

  protected readonly filteredOrders = computed(() => {
    const term = this.searchTerm().toLowerCase();
    const status = this.statusFilter();
    let list = this.orders();

    if (status !== 'all') {
      list = list.filter((o) => o.status === status);
    }

    if (term) {
      list = list.filter(
        (o) => o.order_number.toLowerCase().includes(term),
      );
    }

    return list;
  });

  constructor() {
    this.orderService.load();
    const sub = this.route.queryParamMap.subscribe(() => {});
    this.destroyRef.onDestroy(() => sub.unsubscribe());
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected refresh(): void {
    this.orderService.load();
  }

  protected openOrder(id: number): void {
    this.router.navigate(['/orders', id]);
  }

  protected goToPage(page: number): void {
    this.orderService.load({ page });
  }
}