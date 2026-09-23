import { Component, inject, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { OrderService } from '../../../core/services/order.service';
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

  protected readonly orders = this.orderService.orders;
  protected readonly loading = this.orderService.loading;
  protected readonly error = this.orderService.error;
  protected readonly currentPage = this.orderService.currentPage;
  protected readonly lastPage = this.orderService.lastPage;

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

  protected readonly filteredOrders = computed(() => {
    const term = this.searchTerm().toLowerCase();
    const status = this.statusFilter();
    let list = this.orders();

    if (status !== 'all') {
      list = list.filter((o) => o.status === status);
    }

    if (term) {
      list = list.filter(
        (o) =>
          o.order_number.toLowerCase().includes(term) ||
          (o.customer?.name?.toLowerCase() ?? '').includes(term) ||
          (o.store?.name?.toLowerCase() ?? '').includes(term),
      );
    }

    return list;
  });

  constructor() {
    this.orderService.load();
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected goToPage(page: number): void {
    this.orderService.load({ page });
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