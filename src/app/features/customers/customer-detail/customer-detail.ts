import { Component, inject, signal, DestroyRef } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { CustomerService } from '../../../core/services/customer.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { AvatarComponent } from '../../../shared/components/avatar/avatar';
import { CardComponent } from '../../../shared/components/card/card';
import { Customer } from '../../../core/models';

@Component({
  selector: 'app-customer-detail',
  standalone: true,
  imports: [
    DatePipe,
    CurrencyPipe,
    RouterLink,
    StatusBadgeComponent,
    SkeletonComponent,
    ErrorStateComponent,
    EmptyStateComponent,
    AvatarComponent,
    CardComponent,
  ],
  templateUrl: './customer-detail.html',
  styleUrl: './customer-detail.css',
})
export class CustomerDetailComponent {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private customerService = inject(CustomerService);
  private destroyRef = inject(DestroyRef);

  protected readonly customer = signal<Customer | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.loadCustomer(id);
    });
    this.destroyRef.onDestroy(() => sub.unsubscribe());
  }

  private loadCustomer(id: number): void {
    this.loading.set(true);
    this.error.set(null);

    this.customerService.getCustomer(id).subscribe({
      next: (customer) => {
        this.customer.set(customer);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('We couldn\'t load this customer.');
        this.loading.set(false);
      },
    });
  }

  protected retry(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loadCustomer(id);
  }

  protected goBack(): void {
    this.router.navigate(['/customers']);
  }
}