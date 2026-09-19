import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Product, Category } from '../models';
import { Observable, map } from 'rxjs';

export interface ProductFilters {
  category_id?: string;
  search?: string;
}

interface RawProduct {
  id: number;
  store_id: number;
  category_id: number | null;
  name: string;
  description: string | null;
  sku: string | null;
  price: number;
  image: string | null;
  stock: number | null;
  is_available: boolean;
  category?: Category | null;
  created_at: string;
}

@Injectable({ providedIn: 'root' })
export class ProductService {
  private api = inject(ApiClientService);

  private _products = signal<Product[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  products = this._products.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(filters: ProductFilters = {}): void {
    this._loading.set(true);
    this._error.set(null);

    this.getProducts(filters).subscribe({
      next: (products) => {
        this._products.set(products);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load products.');
        this._loading.set(false);
      },
    });
  }

  getProducts(filters: ProductFilters = {}): Observable<Product[]> {
    const params: Record<string, string> = {};
    if (filters.category_id) params['category_id'] = filters.category_id;
    if (filters.search) params['search'] = filters.search;

    return this.api
      .get<{ data: RawProduct[] }>('/store/products', params)
      .pipe(map((response) => (response.data ?? response).map((p) => this.toProduct(p))));
  }

  getProduct(id: number): Observable<Product> {
    return this.api.get<RawProduct>(`/store/products/${id}`).pipe(map((p) => this.toProduct(p)));
  }

  createProduct(product: Partial<Product>): Observable<Product> {
    return this.api
      .post<RawProduct>('/store/products', this.toPayload(product))
      .pipe(map((p) => this.toProduct(p)));
  }

  updateProduct(id: number, product: Partial<Product>): Observable<Product> {
    return this.api
      .put<RawProduct>(`/store/products/${id}`, this.toPayload(product))
      .pipe(map((p) => this.toProduct(p)));
  }

  deleteProduct(id: number): Observable<void> {
    return this.api.delete<void>(`/store/products/${id}`);
  }

  private toPayload(product: Partial<Product>): Record<string, unknown> {
    const payload: Record<string, unknown> = {};
    if (product.name !== undefined) payload['name'] = product.name;
    if (product.description !== undefined) payload['description'] = product.description;
    if (product.sku !== undefined) payload['sku'] = product.sku;
    if (product.price !== undefined) payload['price'] = product.price;
    if (product.image !== undefined) payload['image'] = product.image;
    if (product.stock !== undefined) payload['stock'] = product.stock;
    if (product.category_id !== undefined) payload['category_id'] = product.category_id;
    if (product.is_available !== undefined) payload['is_available'] = product.is_available;
    return payload;
  }

  private toProduct(raw: RawProduct): Product {
    return {
      id: raw.id,
      store_id: raw.store_id,
      category_id: raw.category_id,
      name: raw.name,
      description: raw.description ?? undefined,
      sku: raw.sku ?? undefined,
      price: raw.price,
      image: raw.image ?? undefined,
      stock: raw.stock ?? undefined,
      is_available: raw.is_available,
      category: raw.category ?? null,
      created_at: raw.created_at,
    };
  }
}