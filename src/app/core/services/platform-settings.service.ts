import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../api/api-client.service';
import { PlatformSettings } from '../models';

@Injectable({ providedIn: 'root' })
export class PlatformSettingsService {
  private api = inject(ApiClientService);

  get(): Observable<PlatformSettings> {
    return this.api.get<PlatformSettings>('/admin/settings');
  }

  update(settings: PlatformSettings): Observable<PlatformSettings> {
    return this.api.put<PlatformSettings>('/admin/settings', settings);
  }
}
