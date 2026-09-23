import { Component, inject, signal, computed, DestroyRef } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { CurrencyPipe } from '@angular/common';
import { StoreService } from '../../../core/services/store.service';
import { ToastService } from '../../../core/services/toast.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { DropdownComponent } from '../../../shared/components/dropdown/dropdown';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { ButtonComponent } from '../../../shared/components/button/button';
import { Product } from '../../../core/models';

@Component({
  selector: 'app-product-list',
  standalone: true,
  imports: [
    CurrencyPipe,
    StatusBadgeComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    DropdownComponent,
    ConfirmDialogComponent,
    SearchInputComponent,
    ButtonComponent,
  ],
  templateUrl: './product-list.html',
  styleUrl: './product-list.css',
})
export class ProductListComponent {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private storeService = inject(StoreService);
  private toastService = inject(ToastService);
  private destroyRef = inject(DestroyRef);

  protected readonly storeId = signal<number>(0);
  protected readonly storeName = signal('');
  protected readonly products = signal<Product[]>([]);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);

  protected readonly searchTerm = signal('');
  protected readonly deleteTarget = signal<Product | null>(null);
  protected readonly acting = signal(false);

  protected readonly filteredProducts = computed(() => {
    const term = this.searchTerm().toLowerCase();
    if (!term) return this.products();
    return this.products().filter(
      (p) =>
        p.name.toLowerCase().includes(term) ||
        p.sku.toLowerCase().includes(term) ||
        p.category.toLowerCase().includes(term),
    );
  });

  protected readonly availableCount = computed(
    () => this.products().filter((p) => p.available).length,
  );
  protected readonly outOfStock = computed(
    () => this.products().filter((p) => p.stock === 0).length,
  );

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.storeId.set(id);
      this.load(id);
    });
    this.destroyRef.onDestroy(() => sub.unsubscribe());
  }

  private load(storeId: number): void {
    this.loading.set(true);
    this.error.set(null);

    this.storeService.getStore(storeId).subscribe({
      next: (store) => {
        this.storeName.set(store.name);
      },
      error: () => {},
    });

    this.storeService.listProducts(storeId).subscribe({
      next: (products) => {
        this.products.set(products);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('We couldn\'t load products.');
        this.loading.set(false);
      },
    });
  }

  protected retry(): void {
    this.load(this.storeId());
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected goBack(): void {
    const id = this.storeId();
    if (id) {
      this.router.navigate(['/stores', id]);
    } else {
      this.router.navigate(['/stores']);
    }
  }

  protected onCreate(): void {
    this.toastService.show('Product creation is not available yet', 'error');
  }

  protected onRowAction(action: string, product: Product): void {
    if (action === 'Activate' || action === 'Deactivate') {
      this.toggleProduct(product);
    } else if (action === 'Delete') {
      this.deleteTarget.set(product);
    } else if (action === 'Edit') {
      this.toastService.show('Editing products is coming soon', 'error');
    }
  }

  private toggleProduct(product: Product): void {
    const active = !product.available;
    this.storeService.setProductActive(product.id, active).subscribe({
      next: (updated) => {
        this.products.update((list) =>
          list.map((p) => (p.id === updated.id ? updated : p)),
        );
        this.toastService.show(active ? 'Product activated' : 'Product deactivated');
      },
      error: () => {
        this.toastService.show('Unable to update product', 'error');
      },
    });
  }

  protected confirmDelete(): void {
    const product = this.deleteTarget();
    if (!product) return;

    this.acting.set(true);
    this.storeService.deleteProduct(product.id).subscribe({
      next: () => {
        this.products.update((list) => list.filter((p) => p.id !== product.id));
        this.deleteTarget.set(null);
        this.acting.set(false);
        this.toastService.show('Product deleted');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to delete product', 'error');
      },
    });
  }

  protected trackById(_: number, product: Product): number {
    return product.id;
  }
}