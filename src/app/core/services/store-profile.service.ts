import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Store } from '../models';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class StoreProfileService {
  private api = inject(ApiClientService);

  private _profile = signal<Store | null>(null);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  profile = this._profile.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(): void {
    this._loading.set(true);
    this._error.set(null);

    this.getProfile().subscribe({
      next: (profile) => {
        this._profile.set(profile);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load your store profile.');
        this._loading.set(false);
      },
    });
  }

  getProfile(): Observable<Store> {
    return this.api.get<Store>('/store/profile');
  }

  updateProfile(store: Partial<Store>): Observable<Store> {
    return this.api.put<Store>('/store/profile', store);
  }
}