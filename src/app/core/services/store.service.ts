import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Store, Product } from '../models';
import { Observable, map } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class StoreService {
  private api = inject(ApiClientService);

  private _stores = signal<Store[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  stores = this._stores.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(): void {
    this._loading.set(true);
    this._error.set(null);

    this.getStores().subscribe({
      next: (stores) => {
        this._stores.set(stores);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load stores.');
        this._loading.set(false);
      },
    });
  }

  getStore(id: number): Observable<Store> {
    return this.api.get<Store>(`/admin/stores/${id}`);
  }

  createStore(store: Partial<Store>): Observable<Store> {
    return this.api.post<Store>('/admin/stores', store);
  }

  updateStore(id: number, store: Partial<Store>): Observable<Store> {
    return this.api.put<Store>(`/admin/stores/${id}`, store);
  }

  setActive(id: number, active: boolean): Observable<Store> {
    return this.api.put<Store>(`/admin/stores/${id}`, {
      status: active ? 'ACTIVE' : 'INACTIVE',
    });
  }

  listProducts(storeId: number): Observable<Product[]> {
    return this.api.get<Product[]>(`/stores/${storeId}/products`);
  }

  createProduct(storeId: number, product: Partial<Product>): Observable<Product> {
    return this.api.post<Product>(`/admin/stores/${storeId}/products`, product);
  }

  updateProduct(productId: number, product: Partial<Product>): Observable<Product> {
    return this.api.put<Product>(`/admin/products/${productId}`, product);
  }

  deleteProduct(productId: number): Observable<void> {
    return this.api.delete(`/admin/products/${productId}`);
  }

  setProductActive(productId: number, active: boolean): Observable<Product> {
    return this.api.put<Product>(`/admin/products/${productId}`, {
      available: active,
    });
  }

  private getStores(): Observable<Store[]> {
    return this.api
      .get<{ data: Store[] }>('/admin/stores')
      .pipe(map((response) => response.data ?? response));
  }
}