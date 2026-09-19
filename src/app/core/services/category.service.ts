import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Category } from '../models';
import { Observable, map } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class CategoryService {
  private api = inject(ApiClientService);

  private _categories = signal<Category[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  categories = this._categories.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(): void {
    this._loading.set(true);
    this._error.set(null);

    this.getCategories().subscribe({
      next: (categories) => {
        this._categories.set(categories);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load categories.');
        this._loading.set(false);
      },
    });
  }

  getCategories(): Observable<Category[]> {
    return this.api
      .get<{ data: Category[] }>('/store/categories')
      .pipe(map((response) => response.data ?? response));
  }

  getCategory(id: number): Observable<Category> {
    return this.api.get<Category>(`/store/categories/${id}`);
  }

  createCategory(category: Partial<Category>): Observable<Category> {
    return this.api.post<Category>('/store/categories', {
      name: category.name,
      description: category.description,
    });
  }

  updateCategory(id: number, category: Partial<Category>): Observable<Category> {
    return this.api.put<Category>(`/store/categories/${id}`, {
      name: category.name,
      description: category.description,
    });
  }

  deleteCategory(id: number): Observable<void> {
    return this.api.delete<void>(`/store/categories/${id}`);
  }
}