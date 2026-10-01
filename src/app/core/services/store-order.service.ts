import { Injectable, inject, signal, effect } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { EchoService } from '../echo/echo.service';
import { Order, PaginatedResponse } from '../models';
import { map, Observable } from 'rxjs';

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
  private hasLoaded = false;

  constructor() {
    effect(() => {
      const update = this.echoService.orderUpdated$();
      const delivery = this.echoService.deliveryUpdated$();
      if (update || delivery) {
        this.refresh();
      }
    });
    effect(() => {
      const connectionVersion = this.echoService.connectionVersion$();
      if (connectionVersion > 0 && this.hasLoaded) {
        this.refresh();
      }
    });
  }

  load(filters: OrderFilters = {}): void {
    this.hasLoaded = true;
    this.lastFilters = filters;
    this._loading.set(true);
    this._error.set(null);

    const params: Record<string, string> = {};
    if (filters.status) params['status'] = filters.status;
    if (filters.search) params['search'] = filters.search;
    if (filters.page) params['page'] = String(filters.page);

    this.api.get<PaginatedResponse<Order>>('/store/orders', params).subscribe({
      next: (result) => {
        const orders = result.data.map((order) => this.normalizeOrder(order));
        this._orders.set(orders);
        this._total.set(result.meta?.total ?? result.data.length);
        this._currentPage.set(result.meta?.current_page ?? 1);
        this._lastPage.set(result.meta?.last_page ?? 1);
        this._loading.set(false);
      },
      error: () => {
        this._error.set("We couldn't load orders.");
        this._loading.set(false);
      },
    });
  }

  refresh(): void {
    this.load(this.lastFilters);
  }

  getOrder(id: number): Observable<Order> {
    return this.api
      .get<Order>(`/store/orders/${id}`)
      .pipe(map((order) => this.normalizeOrder(order)));
  }

  confirm(id: number): Observable<Order> {
    return this.api
      .post<Order>(`/store/orders/${id}/confirm`, {})
      .pipe(map((order) => this.normalizeOrder(order)));
  }

  preparing(id: number): Observable<Order> {
    return this.api
      .post<Order>(`/store/orders/${id}/preparing`, {})
      .pipe(map((order) => this.normalizeOrder(order)));
  }

  ready(id: number): Observable<Order> {
    return this.api
      .post<Order>(`/store/orders/${id}/ready`, {})
      .pipe(map((order) => this.normalizeOrder(order)));
  }

  cancel(id: number, reason: string): Observable<Order> {
    return this.api
      .post<Order>(`/store/orders/${id}/cancel`, { reason })
      .pipe(map((order) => this.normalizeOrder(order)));
  }

  private normalizeOrder(order: Order): Order {
    return {
      ...order,
      subtotal: this.toFiniteNumber(order.subtotal),
      delivery_fee: this.toFiniteNumber(order.delivery_fee),
      total: this.toFiniteNumber(order.total),
      items: Array.isArray(order.items)
        ? order.items.map((item) => ({
            ...item,
            quantity: this.toFiniteNumber(item.quantity),
            price: this.toFiniteNumber(item.price),
          }))
        : [],
      delivery: order.delivery
        ? {
            ...order.delivery,
            distance: this.toFiniteNumber(order.delivery.distance),
            delivery_fee: this.toFiniteNumber(order.delivery.delivery_fee),
          }
        : order.delivery,
    };
  }

  private toFiniteNumber(value: unknown): number {
    const parsed = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
}
