import { Injectable, inject } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { StoreCategory } from '../models';

@Injectable({ providedIn: 'root' })
export class StoreCategoryService {
  private readonly api = inject(ApiClientService);
  list() { return this.api.get<StoreCategory[]>('/admin/store-categories'); }
  icons() { return this.api.get<{ key: string; label: string }[]>('/admin/store-categories/icons'); }
  save(category: { name: string; description: string; is_active: boolean; icon: string }, id?: number) {
    return id == null ? this.api.post<StoreCategory>('/admin/store-categories', category)
      : this.api.put<StoreCategory>(`/admin/store-categories/${id}`, category);
  }
}
