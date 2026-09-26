import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { DeliveryZone, PaginatedResponse, ZonePricingPreview } from '../models';
import { Observable } from 'rxjs';

export interface ZoneFilters {
  status?: string;
  search?: string;
}

@Injectable({ providedIn: 'root' })
export class ZoneService {
  private api = inject(ApiClientService);

  private _zones = signal<DeliveryZone[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  zones = this._zones.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(filters: ZoneFilters = {}): void {
    this._loading.set(true);
    this._error.set(null);

    this.getZones(filters).subscribe({
      next: (result) => {
        this._zones.set(result.data);
        this._loading.set(false);
      },
      error: () => {
        this._error.set("We couldn't load delivery zones.");
        this._loading.set(false);
      },
    });
  }

  getZone(id: number): Observable<DeliveryZone> {
    return this.api.get<DeliveryZone>(`/admin/delivery-zones/${id}`);
  }

  createZone(zone: Partial<DeliveryZone>): Observable<DeliveryZone> {
    return this.api.post<DeliveryZone>('/admin/delivery-zones', zone);
  }

  updateZone(id: number, zone: Partial<DeliveryZone>): Observable<DeliveryZone> {
    return this.api.put<DeliveryZone>(`/admin/delivery-zones/${id}`, zone);
  }

  deleteZone(id: number): Observable<void> {
    return this.api.delete(`/admin/delivery-zones/${id}`);
  }

  previewPricing(payload: {
    zone: Partial<DeliveryZone>;
    pickup_latitude: number;
    pickup_longitude: number;
    delivery_latitude: number;
    delivery_longitude: number;
    distance_method: 'STRAIGHT_LINE' | 'ROAD_ROUTE';
  }): Observable<ZonePricingPreview> {
    return this.api.post<ZonePricingPreview>('/admin/delivery-zones/preview', payload);
  }

  private getZones(filters: ZoneFilters): Observable<PaginatedResponse<DeliveryZone>> {
    const params: Record<string, string> = { per_page: '1000' };
    if (filters.status) params['status'] = filters.status;
    if (filters.search) params['search'] = filters.search;
    return this.api.get<PaginatedResponse<DeliveryZone>>('/admin/delivery-zones', params);
  }
}
