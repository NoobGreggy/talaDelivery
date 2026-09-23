import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Rider, User } from '../models';
import { Observable, map } from 'rxjs';

interface RawRider {
  id: number;
  user?: User | null;
  vehicle_type?: string;
  vehicle_plate?: string;
  license_number?: string;
  is_online?: boolean;
  status: Rider['status'];
  current_delivery?: Rider['current_delivery'];
  completed_deliveries: number;
  total_earnings: number;
  created_at: string;
}

@Injectable({ providedIn: 'root' })
export class RiderService {
  private api = inject(ApiClientService);

  private _riders = signal<Rider[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  riders = this._riders.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(): void {
    this.loadFrom(this.getRiders());
  }

  loadAvailable(): void {
    this.loadFrom(this.getRiders({ status: 'ONLINE' }));
  }

  loadPending(): void {
    this.loadFrom(this.getRiders({ status: 'PENDING' }));
  }

  private loadFrom(source: Observable<Rider[]>): void {
    this._loading.set(true);
    this._error.set(null);

    source.subscribe({
      next: (riders) => {
        this._riders.set(riders);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load riders.');
        this._loading.set(false);
      },
    });
  }

  getById(id: number): Rider | undefined {
    return this._riders().find((r) => r.id === id);
  }

  private getRiders(params?: Record<string, string>): Observable<Rider[]> {
    return this.api
      .get<{ data: RawRider[] }>('/admin/riders', params)
      .pipe(map((response) => (response.data ?? response).map((r) => this.toRider(r))));
  }

  getRider(id: number): Observable<Rider> {
    return this.api
      .get<RawRider>(`/admin/riders/${id}`)
      .pipe(map((r) => this.toRider(r)));
  }

  approve(id: number): Observable<Rider> {
    return this.api
      .post<RawRider>(`/admin/riders/${id}/approve`, {})
      .pipe(map((r) => this.toRider(r)));
  }

  reject(id: number, reason: string): Observable<Rider> {
    return this.api
      .post<RawRider>(`/admin/riders/${id}/reject`, { reason })
      .pipe(map((r) => this.toRider(r)));
  }

  suspend(id: number, reason = ''): Observable<Rider> {
    return this.api
      .post<RawRider>(`/admin/riders/${id}/suspend`, reason ? { reason } : {})
      .pipe(map((r) => this.toRider(r)));
  }

  activate(id: number): Observable<Rider> {
    return this.approve(id);
  }

  private toRider(raw: RawRider): Rider {
    return {
      id: raw.id,
      user: raw.user,
      name: raw.user?.name ?? '',
      phone: raw.user?.phone ?? '',
      vehicle_type: raw.vehicle_type,
      vehicle_plate: raw.vehicle_plate,
      vehicle: raw.vehicle_type ?? '',
      plate_number: raw.vehicle_plate ?? '',
      license_number: raw.license_number,
      is_online: raw.is_online,
      status: raw.status,
      current_delivery: raw.current_delivery,
      completed_deliveries: raw.completed_deliveries,
      total_earnings: raw.total_earnings,
      created_at: raw.created_at,
    };
  }
}