import { Component, inject, signal, DestroyRef } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DatePipe } from '@angular/common';
import { StoreService } from '../../../core/services/store.service';
import { StoreCategoryService } from '../../../core/services/store-category.service';
import { ZoneService } from '../../../core/services/zone.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { CardComponent } from '../../../shared/components/card/card';
import { ToastService } from '../../../core/services/toast.service';
import { Store, StoreCategory, DeliveryZone } from '../../../core/models';

type StoreTab = 'overview' | 'categories' | 'orders' | 'delivery';

@Component({
  selector: 'app-store-detail',
  standalone: true,
  imports: [
    DatePipe,
    RouterLink,
    StatusBadgeComponent,
    SkeletonComponent,
    ErrorStateComponent,
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
  private categoryService = inject(StoreCategoryService);
  private zoneService = inject(ZoneService);
  protected readonly zones = signal<DeliveryZone[]>([]);
  protected readonly zonesLoading = signal(true);
  protected readonly zonesError = signal<string | null>(null);
  protected readonly selectedZones = signal<number[]>([]);
  protected readonly zonesSaving = signal(false);

  protected readonly store = signal<Store | null>(null);
  protected readonly categories = signal<StoreCategory[]>([]);
  protected readonly categoriesLoading = signal(true);
  protected readonly categoriesError = signal<string | null>(null);
  protected readonly selectedCategories = signal<number[]>([]);
  protected readonly categoriesSaving = signal(false);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);
  protected readonly activeTab = signal<StoreTab>('overview');
  protected readonly toggleStore = signal<Store | null>(null);
  protected readonly acting = signal(false);

  protected readonly tabs: { key: StoreTab; label: string }[] = [
    { key: 'overview', label: 'Overview' },
    { key: 'categories', label: 'Categories' },
    { key: 'orders', label: 'Orders' },
    { key: 'delivery', label: 'Delivery Settings' },
  ];

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      const tab = this.route.snapshot.queryParamMap.get('tab');
      this.activeTab.set(tab === 'categories' || tab === 'delivery' ? tab : 'overview');
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
        this.selectedCategories.set((store.categories ?? []).map((category) => category.id));
        this.selectedZones.set(store.deliveryZoneIds ?? []);
        this.loadZones();
        this.loadCategories();
      },
      error: () => {
        this.error.set('We couldn\'t load this store.');
        this.loading.set(false);
      },
    });
  }

  protected loadCategories(): void {
    this.categoriesLoading.set(true);
    this.categoriesError.set(null);
    this.categoryService.list().subscribe({
      next: (categories) => {
        this.categories.set(categories);
        this.categoriesLoading.set(false);
      },
      error: () => {
        this.categoriesError.set('Unable to load categories.');
        this.categoriesLoading.set(false);
      },
    });
  }

  protected retry(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loadStore(id);
  }

  protected loadZones(): void {
    this.zonesLoading.set(true); this.zonesError.set(null);
    this.zoneService.listAllForAssignment().subscribe({
      next: (zones) => { this.zones.set(zones); this.zonesLoading.set(false); },
      error: () => { this.zonesError.set('Unable to load delivery zones.'); this.zonesLoading.set(false); },
    });
  }

  protected toggleZone(id: number, checked: boolean): void {
    this.selectedZones.update((ids) => checked ? [...new Set([...ids, id])] : ids.filter((value) => value !== id));
  }

  protected saveZones(): void {
    const store = this.store();
    if (!store || this.zonesLoading() || this.zonesSaving() || this.zonesError()) return;
    this.zonesSaving.set(true);
    this.storeService.assignDeliveryZones(store.id, this.selectedZones()).subscribe({
      next: (updated) => {
        this.zonesSaving.set(false);
        if (this.store()?.id === store.id) { this.store.set(updated); this.selectedZones.set(updated.deliveryZoneIds ?? []); }
        this.toastService.show('Store delivery zones saved');
      },
      error: (error) => { this.zonesSaving.set(false); this.toastService.show(error.error?.message ?? 'Unable to save delivery zones', 'error'); },
    });
  }

  protected goBack(): void {
    this.router.navigate(['/stores']);
  }

  protected setTab(tab: StoreTab): void {
    this.activeTab.set(tab);
  }

  protected goToCategories(): void { this.setTab('categories'); }

  protected toggleCategory(id: number, checked: boolean): void {
    this.selectedCategories.update((ids) => checked ? [...new Set([...ids, id])] : ids.filter((value) => value !== id));
  }

  protected saveCategories(): void {
    const store = this.store();
    if (!store || this.categoriesSaving() || this.categoriesLoading() || this.categoriesError()) return;
    this.categoriesSaving.set(true);
    this.storeService.tagCategories(store.id, this.selectedCategories()).subscribe({
      next: (updated) => {
        this.categoriesSaving.set(false);
        if (this.store()?.id === store.id) {
          this.store.set(updated);
          this.selectedCategories.set((updated.categories ?? []).map((category) => category.id));
        }
        this.toastService.show('Store categories saved');
      },
      error: (error) => { this.categoriesSaving.set(false); this.toastService.show(error.error?.message ?? 'Unable to save store categories', 'error'); },
    });
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

}
