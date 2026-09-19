import { Injectable, inject, signal, effect } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { EchoService } from '../echo/echo.service';
import { Order, PaginatedResponse } from '../models';
import { Observable } from 'rxjs';

export interface OrderFilters {
  status?: string;
  search?: string;
  page?: number;
}

@Injectable({ providedIn: 'root' })
export class StoreOrderService {
  private api = inject(ApiClientService);
  private echoService = inject(EchoService);

  private _orders = signal<Order[]>([]);
  private _total = signal(0);
  private _currentPage = signal(1);
  private _lastPage = signal(1);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  orders = this._orders.asReadonly();
  total = this._total.asReadonly();
  currentPage = this._currentPage.asReadonly();
  lastPage = this._lastPage.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  private lastFilters: OrderFilters = {};

  constructor() {
    effect(() => {
      const update = this.echoService.orderUpdated$();
      if (update) {
        this.refresh();
      }
    });
  }

  load(filters: OrderFilters = {}): void {
    this.lastFilters = filters;
    this._loading.set(true);
    this._error.set(null);

    const params: Record<string, string> = {};
    if (filters.status) params['status'] = filters.status;
    if (filters.search) params['search'] = filters.search;
    if (filters.page) params['page'] = String(filters.page);

    this.api.get<PaginatedResponse<Order>>('/store/orders', params).subscribe({
      next: (result) => {
        this._orders.set(result.data);
        this._total.set(result.meta?.total ?? result.data.length);
        this._currentPage.set(result.meta?.current_page ?? 1);
        this._lastPage.set(result.meta?.last_page ?? 1);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load orders.');
        this._loading.set(false);
      },
    });
  }

  refresh(): void {
    this.load(this.lastFilters);
  }

  getOrder(id: number): Observable<Order> {
    return this.api.get<Order>(`/store/orders/${id}`);
  }

  confirm(id: number): Observable<Order> {
    return this.api.post<Order>(`/store/orders/${id}/confirm`, {});
  }

  preparing(id: number): Observable<Order> {
    return this.api.post<Order>(`/store/orders/${id}/preparing`, {});
  }

  ready(id: number): Observable<Order> {
    return this.api.post<Order>(`/store/orders/${id}/ready`, {});
  }

  cancel(id: number, reason: string): Observable<Order> {
    return this.api.post<Order>(`/store/orders/${id}/cancel`, { reason });
  }
}