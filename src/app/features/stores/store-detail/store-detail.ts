import { Component, inject, signal, DestroyRef } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { StoreService } from '../../../core/services/store.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { CardComponent } from '../../../shared/components/card/card';
import { ToastService } from '../../../core/services/toast.service';
import { Store, Product } from '../../../core/models';

type StoreTab = 'overview' | 'products' | 'orders' | 'delivery';

@Component({
  selector: 'app-store-detail',
  standalone: true,
  imports: [
    DatePipe,
    CurrencyPipe,
    RouterLink,
    StatusBadgeComponent,
    SkeletonComponent,
    ErrorStateComponent,
    EmptyStateComponent,
    ButtonComponent,
    ConfirmDialogComponent,
    CardComponent,
  ],
  templateUrl: './store-detail.html',
  styleUrl: './store-detail.css',
})
export class StoreDetailComponent {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private storeService = inject(StoreService);
  private toastService = inject(ToastService);
  private destroyRef = inject(DestroyRef);

  protected readonly store = signal<Store | null>(null);
  protected readonly products = signal<Product[]>([]);
  protected readonly productsLoading = signal(true);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);
  protected readonly activeTab = signal<StoreTab>('overview');
  protected readonly toggleStore = signal<Store | null>(null);
  protected readonly acting = signal(false);

  protected readonly tabs: { key: StoreTab; label: string }[] = [
    { key: 'overview', label: 'Overview' },
    { key: 'products', label: 'Products' },
    { key: 'orders', label: 'Orders' },
    { key: 'delivery', label: 'Delivery Settings' },
  ];

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.loadStore(id);
    });
    this.destroyRef.onDestroy(() => sub.unsubscribe());
  }

  private loadStore(id: number): void {
    this.loading.set(true);
    this.error.set(null);

    this.storeService.getStore(id).subscribe({
      next: (store) => {
        this.store.set(store);
        this.loading.set(false);
        this.loadProducts(id);
      },
      error: () => {
        this.error.set('We couldn\'t load this store.');
        this.loading.set(false);
      },
    });
  }

  private loadProducts(storeId: number): void {
    this.productsLoading.set(true);

    this.storeService.listProducts(storeId).subscribe({
      next: (products) => {
        this.products.set(products);
        this.productsLoading.set(false);
      },
      error: () => {
        this.products.set([]);
        this.productsLoading.set(false);
      },
    });
  }

  protected retry(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loadStore(id);
  }

  protected goBack(): void {
    this.router.navigate(['/stores']);
  }

  protected setTab(tab: StoreTab): void {
    this.activeTab.set(tab);
  }

  protected goToProducts(): void {
    const store = this.store();
    if (store) {
      this.router.navigate(['/stores', store.id, 'products']);
    }
  }

  protected confirmToggle(): void {
    const store = this.toggleStore();
    if (!store) return;

    const active = store.status !== 'ACTIVE';
    this.acting.set(true);

    this.storeService.setActive(store.id, active).subscribe({
      next: () => {
        this.store.set({ ...store, status: active ? 'ACTIVE' : 'INACTIVE' });
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

  protected trackById(_: number, product: Product): number {
    return product.id;
  }
}