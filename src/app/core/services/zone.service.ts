import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import {
  DeliveryZone,
  DeliveryZoneWrite,
  PaginatedResponse,
  PlaceBoundaryResult,
  ZonePricingPreview,
} from '../models';
import { Observable, map, expand, reduce, EMPTY } from 'rxjs';

/**
 * Decimal columns come off the wire as strings (`"base_fee":"49.00"`, mirroring
 * the Laravel decimal casts). `toZone` coerces them so the read model stays
 * number-typed for templates, sorting and currency pipes.
 */
type RawZone = Record<string, unknown> & { id: number };

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
        this._zones.set(result.data.map((zone) => this.toZone(zone)));
        this._loading.set(false);
      },
      error: () => {
        this._error.set("We couldn't load delivery zones.");
        this._loading.set(false);
      },
    });
  }

  getZone(id: number): Observable<DeliveryZone> {
    return this.api
      .get<RawZone>(`/admin/delivery-zones/${id}`)
      .pipe(map((raw) => this.toZone(raw)));
  }

  listAllForAssignment(): Observable<DeliveryZone[]> {
    const page = (number: number) => this.api.get<PaginatedResponse<RawZone>>('/admin/delivery-zones', { page: String(number), per_page: '100' });
    return page(1).pipe(
      expand((result) => result.meta.current_page < result.meta.last_page ? page(result.meta.current_page + 1) : EMPTY),
      reduce((zones, result) => [...zones, ...result.data.map((zone) => this.toZone(zone))], [] as DeliveryZone[]),
    );
  }

  createZone(zone: DeliveryZoneWrite): Observable<DeliveryZone> {
    return this.api.post<RawZone>('/admin/delivery-zones', zone).pipe(map((raw) => this.toZone(raw)));
  }

  updateZone(id: number, zone: DeliveryZoneWrite): Observable<DeliveryZone> {
    return this.api
      .put<RawZone>(`/admin/delivery-zones/${id}`, zone)
      .pipe(map((raw) => this.toZone(raw)));
  }

  deleteZone(id: number): Observable<void> {
    return this.api.delete(`/admin/delivery-zones/${id}`);
  }

  previewPricing(payload: {
    zone: DeliveryZoneWrite;
    pickup_latitude: string;
    pickup_longitude: string;
    delivery_latitude: string;
    delivery_longitude: string;
    distance_method?: 'STRAIGHT_LINE' | 'ROAD_ROUTE';
  }): Observable<ZonePricingPreview> {
    return this.api.post<ZonePricingPreview>('/admin/delivery-zones/preview', payload);
  }

  searchBoundaries(query: string, type: 'city' | 'province'): Observable<PlaceBoundaryResult[]> {
    return this.api.get<PlaceBoundaryResult[]>('/admin/place-boundaries', { query, type });
  }

  private toZone(raw: RawZone): DeliveryZone {
    const toNumber = (value: unknown): number => {
      const parsed = typeof value === 'number' ? value : Number(value);
      return Number.isFinite(parsed) ? parsed : 0;
    };
    const toOptionalNumber = (value: unknown): number | null => {
      if (value === null || value === undefined || value === '') return null;
      const parsed = typeof value === 'number' ? value : Number(value);
      return Number.isFinite(parsed) ? parsed : null;
    };

    return {
      ...(raw as unknown as DeliveryZone),
      base_fee: toNumber(raw['base_fee']),
      tala_coins_percent: toNumber(raw['tala_coins_percent']),
      included_km: toNumber(raw['included_km']),
      maximum_delivery_km: toOptionalNumber(raw['maximum_delivery_km']),
      extra_fee_per_km: toNumber(raw['extra_fee_per_km']),
      maximum_delivery_fee: toOptionalNumber(raw['maximum_delivery_fee']),
      distance_rounding_km: toNumber(raw['distance_rounding_km']),
    };
  }

  private getZones(filters: ZoneFilters): Observable<PaginatedResponse<RawZone>> {
    const params: Record<string, string> = { per_page: '1000' };
    if (filters.status) params['status'] = filters.status;
    if (filters.search) params['search'] = filters.search;
    return this.api.get<PaginatedResponse<RawZone>>('/admin/delivery-zones', params);
  }
}
