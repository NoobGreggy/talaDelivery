import { Component, inject, signal, computed } from '@angular/core';
import { CurrencyPipe } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ZoneService } from '../../../core/services/zone.service';
import { ToastService } from '../../../core/services/toast.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { ButtonComponent } from '../../../shared/components/button/button';
import { DeliveryZone } from '../../../core/models';

@Component({
  selector: 'app-zone-list',
  standalone: true,
  imports: [
    CurrencyPipe,
    ReactiveFormsModule,
    StatusBadgeComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    ModalComponent,
    ConfirmDialogComponent,
    ButtonComponent,
  ],
  templateUrl: './zone-list.html',
  styleUrl: './zone-list.css',
})
export class ZoneListComponent {
  private zoneService = inject(ZoneService);
  private toastService = inject(ToastService);
  private fb = inject(FormBuilder);

  protected readonly zones = this.zoneService.zones;
  protected readonly loading = this.zoneService.loading;
  protected readonly error = this.zoneService.error;

  protected readonly statusFilter = signal('all');
  protected readonly formModalOpen = signal(false);
  protected readonly editingZone = signal<DeliveryZone | null>(null);
  protected readonly deleteTarget = signal<DeliveryZone | null>(null);
  protected readonly acting = signal(false);

  protected readonly activeCount = computed(
    () => this.zones().filter((z) => z.status === 'ACTIVE').length,
  );

  protected readonly filteredZones = computed(() => {
    const status = this.statusFilter();
    if (status === 'all') return this.zones();
    return this.zones().filter((z) => z.status === status);
  });

  protected readonly form = this.fb.group({
    name: ['', Validators.required],
    city: ['', Validators.required],
    province: [''],
    base_fee: [0, [Validators.required, Validators.min(0)]],
    included_km: [0, [Validators.required, Validators.min(0)]],
    extra_fee_per_km: [0, [Validators.required, Validators.min(0)]],
  });

  constructor() {
    this.zoneService.load();
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected refresh(): void {
    this.zoneService.load();
  }

  protected openCreate(): void {
    this.editingZone.set(null);
    this.form.reset({
      name: '',
      city: '',
      province: '',
      base_fee: 0,
      included_km: 0,
      extra_fee_per_km: 0,
    });
    this.formModalOpen.set(true);
  }

  protected openEdit(zone: DeliveryZone): void {
    this.editingZone.set(zone);
    this.form.setValue({
      name: zone.name,
      city: zone.city ?? '',
      province: zone.province ?? '',
      base_fee: zone.base_fee,
      included_km: zone.included_km,
      extra_fee_per_km: zone.extra_fee_per_km,
    });
    this.formModalOpen.set(true);
  }

  protected closeModal(): void {
    this.formModalOpen.set(false);
    this.editingZone.set(null);
  }

  protected save(): void {
    if (this.form.invalid) return;

    const editing = this.editingZone();
    const raw = this.form.getRawValue();
    const payload: Partial<DeliveryZone> = {
      name: raw.name ?? '',
      city: raw.city ?? '',
      province: raw.province ?? '',
      base_fee: raw.base_fee ?? 0,
      included_km: raw.included_km ?? 0,
      extra_fee_per_km: raw.extra_fee_per_km ?? 0,
    };
    this.acting.set(true);

    const request = editing
      ? this.zoneService.updateZone(editing.id, payload)
      : this.zoneService.createZone(payload);

    request.subscribe({
      next: () => {
        this.acting.set(false);
        this.closeModal();
        this.zoneService.load();
        this.toastService.show(editing ? 'Zone updated' : 'Zone created');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to save zone', 'error');
      },
    });
  }

  protected toggleStatus(zone: DeliveryZone): void {
    const active = zone.status !== 'ACTIVE';
    this.acting.set(true);

    this.zoneService.updateZone(zone.id, { status: active ? 'ACTIVE' : 'INACTIVE' }).subscribe({
      next: () => {
        this.acting.set(false);
        this.zoneService.load();
        this.toastService.show(active ? 'Zone activated' : 'Zone deactivated');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to update zone', 'error');
      },
    });
  }

  protected confirmDelete(): void {
    const zone = this.deleteTarget();
    if (!zone) return;

    this.acting.set(true);
    this.zoneService.deleteZone(zone.id).subscribe({
      next: () => {
        this.acting.set(false);
        this.deleteTarget.set(null);
        this.zoneService.load();
        this.toastService.show('Zone deleted');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to delete zone', 'error');
      },
    });
  }

  protected trackById(_: number, zone: DeliveryZone): number {
    return zone.id;
  }

  protected zoneLocation(zone: DeliveryZone): string {
    return [zone.city, zone.province].filter((v) => v).join(', ');
  }
}
