import { Component, inject, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { StoreService } from '../../../core/services/store.service';
import { ToastService } from '../../../core/services/toast.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { DropdownComponent } from '../../../shared/components/dropdown/dropdown';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { ButtonComponent } from '../../../shared/components/button/button';
import { Store } from '../../../core/models';

@Component({
  selector: 'app-store-list',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    StatusBadgeComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    DropdownComponent,
    ConfirmDialogComponent,
    SearchInputComponent,
    ModalComponent,
    ButtonComponent,
  ],
  templateUrl: './store-list.html',
  styleUrl: './store-list.css',
})
export class StoreListComponent {
  private storeService = inject(StoreService);
  private router = inject(Router);
  private toastService = inject(ToastService);
  private fb = inject(FormBuilder);

  protected readonly stores = this.storeService.stores;
  protected readonly loading = this.storeService.loading;
  protected readonly error = this.storeService.error;

  protected readonly searchTerm = signal('');
  protected readonly statusFilter = signal('all');
  protected readonly toggleStore = signal<Store | null>(null);
  protected readonly acting = signal(false);
  protected readonly createModalOpen = signal(false);
  protected readonly createError = signal<string | null>(null);

  protected readonly createForm = this.fb.group({
    name: ['', Validators.required],
    description: [''],
    phone: [''],
    email: ['', Validators.email],
    address: ['', Validators.required],
    latitude: [null as number | null],
    longitude: [null as number | null],
    opening_time: [''],
    closing_time: [''],
    merchant_name: ['', Validators.required],
    merchant_email: ['', [Validators.required, Validators.email]],
    merchant_password: ['', [Validators.required, Validators.minLength(8)]],
    merchant_phone: [''],
  });

  protected readonly filteredStores = computed(() => {
    const term = this.searchTerm().toLowerCase();
    const status = this.statusFilter();
    let list = this.stores();

    if (status !== 'all') {
      list = list.filter((s) => (status === 'active' ? s.status === 'ACTIVE' : s.status !== 'ACTIVE'));
    }

    if (term) {
      list = list.filter(
        (s) => s.name.toLowerCase().includes(term) || s.address.toLowerCase().includes(term),
      );
    }

    return list;
  });

  protected readonly activeCount = computed(
    () => this.stores().filter((s) => s.status === 'ACTIVE').length,
  );
  protected readonly offlineCount = computed(
    () => this.stores().filter((s) => s.status !== 'ACTIVE').length,
  );
  protected readonly ordersToday = computed(
    () => this.stores().reduce((sum, s) => sum + (s.orders_today ?? 0), 0),
  );

  constructor() {
    this.storeService.load();
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected refresh(): void {
    this.storeService.load();
  }

  protected openStore(id: number): void {
    this.router.navigate(['/stores', id]);
  }

  protected openProducts(id: number): void {
    this.router.navigate(['/stores', id, 'products']);
  }

  protected onRowAction(action: string, store: Store): void {
    if (action === 'View') {
      this.openStore(store.id);
    } else if (action === 'Products') {
      this.openProducts(store.id);
    } else if (action === 'Activate' || action === 'Deactivate') {
      this.toggleStore.set(store);
    }
  }

  protected confirmToggle(): void {
    const store = this.toggleStore();
    if (!store) return;

    const active = store.status !== 'ACTIVE';
    this.acting.set(true);

    this.storeService.setActive(store.id, active).subscribe({
      next: () => {
        this.storeService.load();
        this.toggleStore.set(null);
        this.acting.set(false);
        this.toastService.show(active ? 'Store activated' : 'Store deactivated');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to update store', 'error');
      },
    });
  }

  protected openCreateStore(): void {
    this.createForm.reset({});
    this.createError.set(null);
    this.createModalOpen.set(true);
  }

  protected closeCreateStore(): void {
    this.createModalOpen.set(false);
  }

  protected createStore(): void {
    if (this.createForm.invalid) return;

    const raw = this.createForm.getRawValue();
    const payload: Partial<Store> & {
      merchant_name?: string;
      merchant_email?: string;
      merchant_password?: string;
      merchant_phone?: string;
    } = {
      name: raw.name ?? '',
      description: raw.description || undefined,
      phone: raw.phone || undefined,
      email: raw.email || undefined,
      address: raw.address ?? '',
      latitude: raw.latitude ?? undefined,
      longitude: raw.longitude ?? undefined,
      opening_time: raw.opening_time || undefined,
      closing_time: raw.closing_time || undefined,
      merchant_name: raw.merchant_name || undefined,
      merchant_email: raw.merchant_email || undefined,
      merchant_password: raw.merchant_password || undefined,
      merchant_phone: raw.merchant_phone || undefined,
    };
    this.acting.set(true);
    this.createError.set(null);

    this.storeService.createStore(payload).subscribe({
      next: () => {
        this.acting.set(false);
        this.createModalOpen.set(false);
        this.storeService.load();
        this.toastService.show('Store created');
      },
      error: (err: unknown) => {
        this.acting.set(false);
        this.createError.set('Unable to create store. Check the details and try again.');
        this.toastService.show('Unable to create store', 'error');
        console.error(err);
      },
    });
  }

  protected trackById(_: number, store: Store): number {
    return store.id;
  }
}