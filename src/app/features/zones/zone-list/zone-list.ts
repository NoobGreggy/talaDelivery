import { CurrencyPipe, DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import {
  DeliveryZone,
  DeliveryZoneStatus,
  GeoJsonBoundary,
  PlaceBoundaryResult,
  ZonePricingPreview,
} from '../../../core/models';
import { StoreService } from '../../../core/services/store.service';
import { ToastService } from '../../../core/services/toast.service';
import { ZoneService } from '../../../core/services/zone.service';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { ZoneBoundaryMapComponent } from '../zone-boundary-map/zone-boundary-map';

@Component({
  selector: 'app-zone-list',
  standalone: true,
  imports: [
    CurrencyPipe,
    DatePipe,
    ReactiveFormsModule,
    StatusBadgeComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    ModalComponent,
    ConfirmDialogComponent,
    ButtonComponent,
    ZoneBoundaryMapComponent,
  ],
  templateUrl: './zone-list.html',
  styleUrl: './zone-list.css',
})
export class ZoneListComponent {
  private readonly zoneService = inject(ZoneService);
  private readonly storeService = inject(StoreService);
  private readonly toastService = inject(ToastService);
  private readonly fb = inject(FormBuilder);

  protected readonly zones = this.zoneService.zones;
  protected readonly stores = this.storeService.stores;
  protected readonly loading = this.zoneService.loading;
  protected readonly error = this.zoneService.error;
  protected readonly statusFilter = signal('all');
  protected readonly search = signal('');
  protected readonly formModalOpen = signal(false);
  protected readonly editingZone = signal<DeliveryZone | null>(null);
  protected readonly archiveTarget = signal<DeliveryZone | null>(null);
  protected readonly boundary = signal<GeoJsonBoundary | null>(null);
  protected readonly boundaryQuery = signal('');
  protected readonly boundarySearchType = signal<'city' | 'province'>('city');
  protected readonly boundaryResults = signal<PlaceBoundaryResult[]>([]);
  protected readonly boundarySearching = signal(false);
  protected readonly boundarySearchError = signal<string | null>(null);
  protected readonly acting = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly previewing = signal(false);
  protected readonly preview = signal<ZonePricingPreview | null>(null);

  protected readonly activeCount = computed(
    () => this.zones().filter((zone) => zone.status === 'ACTIVE').length,
  );
  protected readonly mappedCount = computed(
    () => this.zones().filter((zone) => zone.boundary_geojson).length,
  );
  protected readonly filteredZones = computed(() => {
    const status = this.statusFilter();
    const search = this.search().trim().toLowerCase();
    return this.zones().filter((zone) => {
      const matchesStatus = status === 'all' || zone.status === status;
      const haystack = `${zone.name} ${zone.city} ${zone.province}`.toLowerCase();
      return matchesStatus && (!search || haystack.includes(search));
    });
  });
  protected readonly citySuggestions = computed(() => [
    ...new Set(
      this.zones()
        .map((zone) => zone.city)
        .filter(Boolean),
    ),
  ]);
  protected readonly provinceSuggestions = computed(() => [
    ...new Set(
      this.zones()
        .map((zone) => zone.province)
        .filter(Boolean),
    ),
  ]);

  protected readonly form = this.fb.group({
    name: ['', Validators.required],
    city: [''],
    province: ['', Validators.required],
    status: ['DRAFT' as DeliveryZoneStatus, Validators.required],
    base_fee: [49, [Validators.required, Validators.min(0)]],
    included_km: [5, [Validators.required, Validators.min(0)]],
    maximum_delivery_km: [20 as number | null, Validators.min(0.1)],
    extra_fee_per_km: [10, [Validators.required, Validators.min(0)]],
    maximum_delivery_fee: [null as number | null, Validators.min(0)],
    distance_rounding_km: [0.5, [Validators.required, Validators.min(0.1)]],
    effective_from: [''],
  });

  protected readonly previewForm = this.fb.group({
    store_id: [null as number | null, Validators.required],
    delivery_latitude: [
      null as number | null,
      [Validators.required, Validators.min(-90), Validators.max(90)],
    ],
    delivery_longitude: [
      null as number | null,
      [Validators.required, Validators.min(-180), Validators.max(180)],
    ],
    distance_method: ['STRAIGHT_LINE' as 'STRAIGHT_LINE' | 'ROAD_ROUTE', Validators.required],
  });

  constructor() {
    this.zoneService.load();
    this.storeService.load();
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected setSearch(value: string): void {
    this.search.set(value);
  }

  protected refresh(): void {
    this.zoneService.load();
  }

  protected openCreate(): void {
    this.editingZone.set(null);
    this.boundary.set(null);
    this.resetBoundarySearch();
    this.formError.set(null);
    this.preview.set(null);
    this.form.reset({
      name: '',
      city: '',
      province: '',
      status: 'DRAFT',
      base_fee: 49,
      included_km: 5,
      maximum_delivery_km: 20,
      extra_fee_per_km: 10,
      maximum_delivery_fee: null,
      distance_rounding_km: 0.5,
      effective_from: '',
    });
    this.previewForm.reset({
      store_id: null,
      delivery_latitude: null,
      delivery_longitude: null,
      distance_method: 'STRAIGHT_LINE',
    });
    this.formModalOpen.set(true);
  }

  protected openEdit(zone: DeliveryZone): void {
    this.zoneService.getZone(zone.id).subscribe({
      next: (detail) => this.populateEditForm(detail),
      error: () => this.toastService.show('Unable to load zone details', 'error'),
    });
  }

  protected closeModal(): void {
    this.formModalOpen.set(false);
    this.editingZone.set(null);
    this.formError.set(null);
    this.preview.set(null);
    this.resetBoundarySearch();
  }

  protected boundaryChanged(boundary: GeoJsonBoundary | null): void {
    this.boundary.set(boundary);
    this.preview.set(null);
  }

  protected setBoundaryQuery(value: string): void {
    this.boundaryQuery.set(value);
    this.boundarySearchError.set(null);
  }

  protected setBoundarySearchType(type: 'city' | 'province'): void {
    this.boundarySearchType.set(type);
    this.boundaryResults.set([]);
    this.boundarySearchError.set(null);
  }

  protected searchEnteredLocation(type: 'city' | 'province'): void {
    const city = this.form.controls.city.value?.trim();
    const province = this.form.controls.province.value?.trim();
    const query =
      type === 'city'
        ? [city, province, 'Philippines'].filter(Boolean).join(', ')
        : [province, 'Philippines'].filter(Boolean).join(', ');
    if ((type === 'city' && !city) || (type === 'province' && !province)) return;

    this.boundarySearchType.set(type);
    this.boundaryQuery.set(query);
    this.searchBoundaries(true);
  }

  protected searchBoundaries(selectSingleResult = false): void {
    const query = this.boundaryQuery().trim();
    if (query.length < 2 || this.boundarySearching()) return;

    this.boundarySearching.set(true);
    this.boundarySearchError.set(null);
    this.boundaryResults.set([]);
    this.zoneService.searchBoundaries(query, this.boundarySearchType()).subscribe({
      next: (results) => {
        this.boundarySearching.set(false);
        if (selectSingleResult && results.length === 1) {
          this.selectBoundary(results[0]);

          return;
        }
        this.boundaryResults.set(results);
        if (results.length === 0) {
          this.boundarySearchError.set(
            'No city or province boundary was found. Try a more specific name.',
          );
        }
      },
      error: (error: HttpErrorResponse) => {
        this.boundarySearching.set(false);
        this.boundarySearchError.set(this.apiError(error, 'Unable to search boundaries.'));
      },
    });
  }

  protected selectBoundary(result: PlaceBoundaryResult): void {
    this.boundary.set(result.geometry);
    this.boundaryResults.set([]);
    this.boundarySearchError.set(null);
    this.preview.set(null);
    this.form.patchValue({
      name: this.form.controls.name.value?.trim() || `${result.name} Zone`,
      city: result.city ?? this.form.controls.city.value,
      province: result.province ?? this.form.controls.province.value,
    });
  }

  protected save(): void {
    if (this.form.invalid || this.acting()) return;
    const editing = this.editingZone();
    this.acting.set(true);
    this.formError.set(null);

    const request = editing
      ? this.zoneService.updateZone(editing.id, this.zonePayload())
      : this.zoneService.createZone(this.zonePayload());

    request.subscribe({
      next: () => {
        this.acting.set(false);
        this.closeModal();
        this.zoneService.load();
        this.toastService.show(editing ? 'Zone updated' : 'Zone created');
      },
      error: (error: HttpErrorResponse) => {
        this.acting.set(false);
        this.formError.set(this.apiError(error, 'Unable to save zone.'));
      },
    });
  }

  protected changeStatus(zone: DeliveryZone, status: DeliveryZoneStatus): void {
    if (this.acting()) return;
    this.acting.set(true);
    this.zoneService.updateZone(zone.id, { status }).subscribe({
      next: () => {
        this.acting.set(false);
        this.zoneService.load();
        this.toastService.show(`Zone ${status.toLowerCase()}`);
      },
      error: (error: HttpErrorResponse) => {
        this.acting.set(false);
        this.toastService.show(this.apiError(error, 'Unable to update zone'), 'error');
      },
    });
  }

  protected confirmArchive(): void {
    const zone = this.archiveTarget();
    if (!zone || this.acting()) return;
    this.acting.set(true);
    this.zoneService.deleteZone(zone.id).subscribe({
      next: () => {
        this.acting.set(false);
        this.archiveTarget.set(null);
        this.zoneService.load();
        this.toastService.show('Zone archived');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to archive zone', 'error');
      },
    });
  }

  protected runPreview(): void {
    if (this.form.invalid || this.previewForm.invalid || this.previewing()) return;
    const preview = this.previewForm.getRawValue();
    const store = this.stores().find((item) => item.id === Number(preview.store_id));
    if (!store || store.latitude == null || store.longitude == null) {
      this.formError.set('The selected store does not have valid pickup coordinates.');
      return;
    }

    this.previewing.set(true);
    this.formError.set(null);
    this.zoneService
      .previewPricing({
        zone: this.zonePayload(),
        pickup_latitude: Number(store.latitude),
        pickup_longitude: Number(store.longitude),
        delivery_latitude: Number(preview.delivery_latitude),
        delivery_longitude: Number(preview.delivery_longitude),
        distance_method: preview.distance_method ?? 'STRAIGHT_LINE',
      })
      .subscribe({
        next: (result) => {
          this.previewing.set(false);
          this.preview.set(result);
        },
        error: (error: HttpErrorResponse) => {
          this.previewing.set(false);
          this.formError.set(this.apiError(error, 'Unable to calculate the preview.'));
        },
      });
  }

  protected zoneLocation(zone: DeliveryZone): string {
    return [zone.city, zone.province].filter(Boolean).join(', ');
  }

  private populateEditForm(zone: DeliveryZone): void {
    this.editingZone.set(zone);
    this.boundary.set(zone.boundary_geojson ?? null);
    this.resetBoundarySearch();
    this.formError.set(null);
    this.preview.set(null);
    this.form.setValue({
      name: zone.name,
      city: zone.city ?? '',
      province: zone.province,
      status: zone.status,
      base_fee: Number(zone.base_fee),
      included_km: Number(zone.included_km),
      maximum_delivery_km:
        zone.maximum_delivery_km == null ? null : Number(zone.maximum_delivery_km),
      extra_fee_per_km: Number(zone.extra_fee_per_km),
      maximum_delivery_fee:
        zone.maximum_delivery_fee == null ? null : Number(zone.maximum_delivery_fee),
      distance_rounding_km: Number(zone.distance_rounding_km),
      effective_from: zone.effective_from ? zone.effective_from.slice(0, 16) : '',
    });
    this.formModalOpen.set(true);
  }

  private zonePayload(): Partial<DeliveryZone> {
    const raw = this.form.getRawValue();
    return {
      name: raw.name ?? '',
      city: raw.city?.trim() || null,
      province: raw.province ?? '',
      status: raw.status ?? 'DRAFT',
      boundary_geojson: this.boundary(),
      base_fee: Number(raw.base_fee ?? 0),
      included_km: Number(raw.included_km ?? 0),
      maximum_delivery_km: raw.maximum_delivery_km == null ? null : Number(raw.maximum_delivery_km),
      extra_fee_per_km: Number(raw.extra_fee_per_km ?? 0),
      maximum_delivery_fee:
        raw.maximum_delivery_fee == null ? null : Number(raw.maximum_delivery_fee),
      distance_rounding_km: Number(raw.distance_rounding_km ?? 0.1),
      effective_from: raw.effective_from || null,
    };
  }

  private apiError(error: HttpErrorResponse, fallback: string): string {
    const errors = error.error?.errors as Record<string, string[]> | undefined;
    const first = errors ? Object.values(errors).flat()[0] : undefined;
    return first ?? error.error?.message ?? fallback;
  }

  private resetBoundarySearch(): void {
    this.boundaryQuery.set('');
    this.boundarySearchType.set('city');
    this.boundaryResults.set([]);
    this.boundarySearching.set(false);
    this.boundarySearchError.set(null);
  }
}
