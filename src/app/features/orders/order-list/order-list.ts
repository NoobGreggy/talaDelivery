import { Component, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { interval, merge, fromEvent, debounceTime } from 'rxjs';
import { ActivatedRoute, Router } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { OrderService } from '../../../core/services/order.service';
import { RealtimeService } from '../../../core/realtime/realtime.service';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { PaginationComponent } from '../../../shared/components/pagination/pagination';
import { Order } from '../../../core/models';

interface OrderColumn {
  key: string;
  label: string;
}

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
  private orderService = inject(OrderService);
  private router = inject(Router);
  private realtime = inject(RealtimeService);
  private route = inject(ActivatedRoute);
  private storeFilter?: string;

  protected readonly orders = this.orderService.orders;
  protected readonly loading = this.orderService.loading;
  protected readonly error = this.orderService.error;
  protected readonly currentPage = this.orderService.currentPage;
  protected readonly lastPage = this.orderService.lastPage;
  protected readonly total = this.orderService.total;
  protected readonly lastUpdated = this.orderService.lastUpdated;
  protected readonly realtimeStatus = this.realtime.status;
  protected readonly filteredOrders = this.orders;

  protected readonly searchTerm = signal('');
  protected readonly statusFilter = signal('all');

  protected readonly columns: OrderColumn[] = [
    { key: 'order', label: 'Order' },
    { key: 'customer', label: 'Customer' },
    { key: 'store', label: 'Store' },
    { key: 'total', label: 'Total' },
    { key: 'payment', label: 'Payment' },
    { key: 'status', label: 'Status' },
    { key: 'created', label: 'Created' },
  ];

  constructor() {
    this.route.queryParamMap.pipe(takeUntilDestroyed()).subscribe((params) => {
      this.storeFilter = params.get('store') || undefined;
      this.goToPage(1);
    });
    this.realtime.connect();
    merge(this.realtime.orderUpdated$, fromEvent(window, 'focus')).pipe(
      debounceTime(250), takeUntilDestroyed(),
    ).subscribe(() => this.orderService.refresh(true));
    interval(10000).pipe(takeUntilDestroyed()).subscribe(() => {
      if (!document.hidden) this.orderService.refresh(true);
    });
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
    this.goToPage(1);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
    this.goToPage(1);
  }

  protected goToPage(page: number): void {
    this.orderService.load({ page, search: this.searchTerm().trim() || undefined,
      store: this.storeFilter,
      status: this.statusFilter() === 'all' ? undefined : this.statusFilter() });
  }

  protected refresh(): void {
    this.orderService.refresh();
  }

  protected openOrder(id: number): void {
    this.router.navigate(['/orders', id]);
  }

  protected trackById(_: number, order: Order): number {
    return order.id;
  }
}
