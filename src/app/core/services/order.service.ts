import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Order, PaginatedResponse } from '../models';
import { Observable, Subscription } from 'rxjs';

export interface OrderFilters {
  status?: string;
  search?: string;
  store?: string;
  customer?: string;
  payment?: string;
  page?: number;
}

@Injectable({ providedIn: 'root' })
export class OrderService {
  private api = inject(ApiClientService);

  private _orders = signal<Order[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);
  private _total = signal(0);
  private _currentPage = signal(1);
  private _lastPage = signal(1);

  orders = this._orders.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();
  total = this._total.asReadonly();
  currentPage = this._currentPage.asReadonly();
  lastPage = this._lastPage.asReadonly();

  private lastFilters: OrderFilters = {};
  private request?: Subscription;
  private requestVersion = 0;
  private _refreshing = signal(false);
  private _lastUpdated = signal<Date | null>(null);
  refreshing = this._refreshing.asReadonly();
  lastUpdated = this._lastUpdated.asReadonly();

  load(filters: OrderFilters = {}, silent = false): void {
    if (silent && (this._loading() || this._refreshing())) return;
    this.request?.unsubscribe();
    const version = ++this.requestVersion;
    this.lastFilters = filters;
    this._loading.set(!silent);
    this._refreshing.set(silent);
    if (!silent) this._error.set(null);

    this.request = this.getOrders(filters).subscribe({
      next: (result) => {
        if (version !== this.requestVersion) return;
        if (result.meta.current_page > result.meta.last_page) {
          this.load({ ...filters, page: result.meta.last_page });
          return;
        }
        this._orders.set(result.data);
        this._total.set(result.meta.total);
        this._currentPage.set(result.meta.current_page);
        this._lastPage.set(result.meta.last_page);
        this._loading.set(false);
        this._refreshing.set(false);
        this._error.set(null);
        this._lastUpdated.set(new Date());
      },
      error: (error) => {
        if (version !== this.requestVersion) return;
        this._error.set(error.error?.message ?? 'We couldn\'t load orders.');
        this._loading.set(false);
        this._refreshing.set(false);
      },
    });
  }

  refresh(silent = false): void {
    this.load(this.lastFilters, silent);
  }

  getOrder(id: number): Observable<Order> {
    return this.api.get<Order>(`/admin/orders/${id}`);
  }

  private getOrders(filters: OrderFilters): Observable<PaginatedResponse<Order>> {
    const params: Record<string, string> = {};
    if (filters.status) params['status'] = filters.status;
    if (filters.search) params['search'] = filters.search;
    if (filters.store) params['store'] = filters.store;
    if (filters.customer) params['customer'] = filters.customer;
    if (filters.payment) params['payment'] = filters.payment;
    if (filters.page) params['page'] = String(filters.page);
    return this.api.get<PaginatedResponse<Order>>('/admin/orders', params);
  }
}
