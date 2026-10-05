import { Component, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { interval, fromEvent } from 'rxjs';
import { RealtimeService } from '../../../core/realtime/realtime.service';
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
  private realtime = inject(RealtimeService);

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
    { value: 'PICKED_UP', label: 'Picked Up' },
    { value: 'OUT_FOR_DELIVERY', label: 'Out for Delivery' },
    { value: 'DELIVERED', label: 'Delivered' },
    { value: 'CANCELLED', label: 'Cancelled' },
  ];

  protected readonly filteredOrders = this.orders;

  constructor() {
    this.orderService.load();
    this.realtime.connect();
    interval(10000).pipe(takeUntilDestroyed()).subscribe(() => {
      if (!document.hidden) this.orderService.refresh(true);
    });
    fromEvent(window, 'focus').pipe(takeUntilDestroyed()).subscribe(() => this.orderService.refresh(true));
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
    this.goToPage(1);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
    this.goToPage(1);
  }

  protected refresh(): void {
    this.orderService.refresh();
  }

  protected openOrder(id: number): void {
    this.router.navigate(['/orders', id]);
  }

  protected goToPage(page: number): void {
    this.orderService.load({ page, search: this.searchTerm().trim() || undefined,
      status: this.statusFilter() === 'all' ? undefined : this.statusFilter() });
  }
}
