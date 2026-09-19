import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Delivery, PaginatedResponse } from '../models';
import { Observable } from 'rxjs';

export interface DeliveryFilters {
  status?: string;
  search?: string;
  page?: number;
}

@Injectable({ providedIn: 'root' })
export class DeliveryService {
  private api = inject(ApiClientService);

  private _deliveries = signal<Delivery[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);
  private _total = signal(0);
  private _currentPage = signal(1);
  private _lastPage = signal(1);

  deliveries = this._deliveries.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();
  total = this._total.asReadonly();
  currentPage = this._currentPage.asReadonly();
  lastPage = this._lastPage.asReadonly();

  private lastFilters: DeliveryFilters = {};

  load(filters: DeliveryFilters = {}): void {
    this.lastFilters = filters;
    this._loading.set(true);
    this._error.set(null);

    this.getDeliveries(filters).subscribe({
      next: (result) => {
        this._deliveries.set(result.data);
        this._total.set(result.meta.total);
        this._currentPage.set(result.meta.current_page);
        this._lastPage.set(result.meta.last_page);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load deliveries.');
        this._loading.set(false);
      },
    });
  }

  refresh(): void {
    this.load(this.lastFilters);
  }

  getById(id: number): Delivery | undefined {
    return this._deliveries().find((d) => d.id === id);
  }

  private getDeliveries(filters: DeliveryFilters): Observable<PaginatedResponse<Delivery>> {
    const params: Record<string, string> = {};
    if (filters.status) params['status'] = filters.status;
    if (filters.search) params['search'] = filters.search;
    if (filters.page) params['page'] = String(filters.page);
    return this.api.get<PaginatedResponse<Delivery>>('/admin/deliveries', params);
  }

  getDelivery(id: number): Observable<Delivery> {
    return this.api.get<Delivery>(`/admin/deliveries/${id}`);
  }

  assignRider(deliveryId: number, riderId: number): Observable<Delivery> {
    return this.api.post<Delivery>(`/admin/deliveries/${deliveryId}/assign`, { rider_id: riderId });
  }

  cancelDelivery(deliveryId: number): Observable<Delivery> {
    return this.api.post<Delivery>(`/admin/deliveries/${deliveryId}/cancel`, {});
  }
}