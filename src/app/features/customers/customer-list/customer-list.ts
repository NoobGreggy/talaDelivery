import { Component, inject, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import { CurrencyPipe } from '@angular/common';
import { CustomerService } from '../../../core/services/customer.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { DropdownComponent } from '../../../shared/components/dropdown/dropdown';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { AvatarComponent } from '../../../shared/components/avatar/avatar';
import { Customer } from '../../../core/models';

@Component({
  selector: 'app-customer-list',
  standalone: true,
  imports: [
    CurrencyPipe,
    StatusBadgeComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    DropdownComponent,
    SearchInputComponent,
    AvatarComponent,
  ],
  templateUrl: './customer-list.html',
  styleUrl: './customer-list.css',
})
export class CustomerListComponent {
  private customerService = inject(CustomerService);
  private router = inject(Router);

  protected readonly customers = this.customerService.customers;
  protected readonly loading = this.customerService.loading;
  protected readonly error = this.customerService.error;

  protected readonly searchTerm = signal('');
  protected readonly statusFilter = signal('all');

  protected readonly filteredCustomers = computed(() => {
    const term = this.searchTerm().toLowerCase();
    const status = this.statusFilter();
    let list = this.customers();

    if (status !== 'all') {
      list = list.filter((c) => c.status === status);
    }

    if (term) {
      list = list.filter(
        (c) => c.name.toLowerCase().includes(term) || c.phone.toLowerCase().includes(term),
      );
    }

    return list;
  });

  constructor() {
    this.customerService.load();
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected refresh(): void {
    this.customerService.refresh();
  }

  protected openCustomer(id: number): void {
    this.router.navigate(['/customers', id]);
  }

  protected onRowAction(action: string, customer: Customer): void {
    if (action === 'View') {
      this.openCustomer(customer.id);
    }
  }

  protected trackById(_: number, customer: Customer): number {
    return customer.id;
  }
}