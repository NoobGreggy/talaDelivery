import { Component, inject, signal, computed, DestroyRef } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';
import { DatePipe } from '@angular/common';
import { DeliveryService } from '../../../core/services/delivery.service';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { DropdownComponent } from '../../../shared/components/dropdown/dropdown';
import { PaginationComponent } from '../../../shared/components/pagination/pagination';
import { Delivery } from '../../../core/models';

interface DeliveryColumn {
  key: string;
  label: string;
}

@Component({
  selector: 'app-delivery-list',
  standalone: true,
  imports: [
    DatePipe,
    SearchInputComponent,
    StatusBadgeComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    DropdownComponent,
    PaginationComponent,
  ],
  templateUrl: './delivery-list.html',
  styleUrl: './delivery-list.css',
})
export class DeliveryListComponent {
  private deliveryService = inject(DeliveryService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private destroyRef = inject(DestroyRef);

  protected readonly deliveries = this.deliveryService.deliveries;
  protected readonly loading = this.deliveryService.loading;
  protected readonly error = this.deliveryService.error;
  protected readonly currentPage = this.deliveryService.currentPage;
  protected readonly lastPage = this.deliveryService.lastPage;

  protected readonly searchTerm = signal('');
  protected readonly activeTab = signal('all');

  protected readonly selectedDeliveryId = signal<number | null>(null);

  protected readonly tabs: { value: string; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'needs-rider', label: 'Needs Rider' },
    { value: 'active', label: 'Active' },
    { value: 'completed', label: 'Completed' },
    { value: 'failed', label: 'Failed' },
  ];

  protected readonly columns: DeliveryColumn[] = [
    { key: 'delivery', label: 'Delivery' },
    { key: 'store', label: 'Store' },
    { key: 'rider', label: 'Rider' },
    { key: 'status', label: 'Status' },
    { key: 'created', label: 'Created' },
    { key: 'actions', label: '' },
  ];

  protected readonly filteredDeliveries = computed(() => {
    const term = this.searchTerm().toLowerCase();
    let list = this.deliveries();
    const tab = this.activeTab();

    if (tab === 'needs-rider') {
      list = list.filter((d) => d.status === 'FINDING_RIDER');
    } else if (tab === 'active') {
      list = list.filter((d) =>
        ['RIDER_ASSIGNED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'FINDING_RIDER'].includes(d.status),
      );
    } else if (tab === 'completed') {
      list = list.filter((d) => d.status === 'DELIVERED');
    } else if (tab === 'failed') {
      list = list.filter((d) => d.status === 'FAILED' || d.status === 'CANCELLED');
    }

    if (term) {
      list = list.filter(
        (d) =>
          d.delivery_number.toLowerCase().includes(term) ||
          d.store?.name?.toLowerCase().includes(term) ||
          d.rider?.name?.toLowerCase().includes(term) ||
          d.customer?.name?.toLowerCase().includes(term),
      );
    }

    return list;
  });

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = params.get('id');
      this.selectedDeliveryId.set(id ? Number(id) : null);
    });
    this.destroyRef.onDestroy(() => sub.unsubscribe());
  }

  protected setTab(tab: string): void {
    this.activeTab.set(tab);
    this.goToPage(1);
  }

  protected goToPage(page: number): void {
    this.deliveryService.load({ page, status: this.activeTab(), search: this.searchTerm() });
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected refresh(): void {
    this.deliveryService.refresh();
  }

  protected selectDelivery(id: number): void {
    this.router.navigate(['/deliveries', id]);
  }

  protected deliveryMenu(delivery: Delivery): { label: string; icon?: string; danger?: boolean }[] {
    const items: { label: string; icon?: string; danger?: boolean }[] = [
      { label: 'View Detail' },
    ];
    if (delivery.status === 'FINDING_RIDER') {
      items.push({ label: 'Assign Rider' });
    }
    if (!['DELIVERED', 'FAILED', 'CANCELLED'].includes(delivery.status)) {
      items.push({ label: 'Cancel Delivery', danger: true });
    }
    return items;
  }

  protected handleMenuAction(label: string, delivery: Delivery): void {
    if (label === 'View Detail') {
      this.selectDelivery(delivery.id);
    } else if (label === 'Assign Rider') {
      this.router.navigate(['/deliveries', delivery.id], { queryParams: { assign: '1' } });
    } else if (label === 'Cancel Delivery') {
      // Confirmation handled on the detail screen
      this.router.navigate(['/deliveries', delivery.id], { queryParams: { cancel: '1' } });
    }
  }
}