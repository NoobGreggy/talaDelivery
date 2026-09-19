import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { DashboardData } from '../models';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class DashboardService {
  private api = inject(ApiClientService);

  private _data = signal<DashboardData | null>(null);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  data = this._data.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(): void {
    this._loading.set(true);
    this._error.set(null);

    this.getDashboard().subscribe({
      next: (result) => {
        this._data.set(result);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load the dashboard.');
        this._loading.set(false);
      },
    });
  }

  refresh(): void {
    this.load();
  }

  private getDashboard(): Observable<DashboardData> {
    return this.api.get<DashboardData>('/admin/dashboard');
  }
}