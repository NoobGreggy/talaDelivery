import { Injectable, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { Customer } from '../models';
import { Observable, map } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class CustomerService {
  private api = inject(ApiClientService);

  private _customers = signal<Customer[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  customers = this._customers.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(): void {
    this._loading.set(true);
    this._error.set(null);

    this.getCustomers().subscribe({
      next: (customers) => {
        this._customers.set(customers);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('We couldn\'t load customers.');
        this._loading.set(false);
      },
    });
  }

  refresh(): void {
    this.load();
  }

  getCustomer(id: number): Observable<Customer> {
    return this.api.get<Customer>(`/admin/customers/${id}`);
  }

  private getCustomers(): Observable<Customer[]> {
    return this.api
      .get<{ data: Customer[] }>('/admin/customers')
      .pipe(map((response) => response.data ?? response));
  }
}