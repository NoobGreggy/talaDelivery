import { Component, inject, signal, computed, DestroyRef } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { RiderService } from '../../../core/services/rider.service';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { AvatarComponent } from '../../../shared/components/avatar/avatar';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { DropdownComponent } from '../../../shared/components/dropdown/dropdown';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ToastService } from '../../../core/services/toast.service';
import { Rider } from '../../../core/models';

@Component({
  selector: 'app-rider-list',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    SearchInputComponent,
    StatusBadgeComponent,
    AvatarComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    DropdownComponent,
    ConfirmDialogComponent,
    ModalComponent,
    ButtonComponent,
  ],
  templateUrl: './rider-list.html',
  styleUrl: './rider-list.css',
})
export class RiderListComponent {
  private riderService = inject(RiderService);
  private toastService = inject(ToastService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private destroyRef = inject(DestroyRef);

  protected readonly riders = this.riderService.riders;
  protected readonly loading = this.riderService.loading;
  protected readonly error = this.riderService.error;

  protected readonly searchTerm = signal('');
  protected readonly statusFilter = signal('all');

  protected readonly suspendTarget = signal<Rider | null>(null);
  protected readonly suspending = signal(false);

  protected readonly rejectTarget = signal<Rider | null>(null);
  protected readonly rejecting = signal(false);
  protected readonly rejectReason = new FormControl('');

  protected readonly columns: { key: string; label: string }[] = [
    { key: 'rider', label: 'Rider' },
    { key: 'phone', label: 'Phone' },
    { key: 'vehicle', label: 'Vehicle' },
    { key: 'status', label: 'Status' },
    { key: 'delivery', label: 'Current Delivery' },
    { key: 'actions', label: '' },
  ];

  protected readonly statusFilters: { value: string; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'PENDING', label: 'Pending' },
    { value: 'ONLINE', label: 'Online' },
    { value: 'BUSY', label: 'Busy' },
    { value: 'OFFLINE', label: 'Offline' },
    { value: 'REJECTED', label: 'Rejected' },
    { value: 'SUSPENDED', label: 'Suspended' },
  ];

  protected readonly counts = computed(() => {
    const riders = this.riders();
    return {
      pending: riders.filter((r) => r.status === 'PENDING').length,
      online: riders.filter((r) => r.status === 'ONLINE').length,
      busy: riders.filter((r) => r.status === 'BUSY').length,
      offline: riders.filter((r) => r.status === 'OFFLINE').length,
      rejected: riders.filter((r) => r.status === 'REJECTED').length,
      suspended: riders.filter((r) => r.status === 'SUSPENDED').length,
    };
  });

  protected readonly filteredRiders = computed(() => {
    const term = this.searchTerm().toLowerCase();
    const status = this.statusFilter();
    let list = this.riders();

    if (status !== 'all') {
      list = list.filter((r) => r.status === status);
    }

    if (term) {
      list = list.filter(
        (r) =>
          r.name.toLowerCase().includes(term) ||
          r.phone.toLowerCase().includes(term) ||
          r.vehicle.toLowerCase().includes(term),
      );
    }

    return list;
  });

  constructor() {
    this.riderService.load();
    const sub = this.route.paramMap.subscribe(() => {});
    this.destroyRef.onDestroy(() => sub.unsubscribe());
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected refresh(): void {
    this.riderService.load();
  }

  protected openRider(id: number): void {
    this.router.navigate(['/riders', id]);
  }

  protected riderMenu(rider: Rider): { label: string; icon?: string; danger?: boolean }[] {
    const items: { label: string; icon?: string; danger?: boolean }[] = [
      { label: 'View Detail' },
    ];
    if (rider.status === 'PENDING') {
      items.push({ label: 'Approve Rider' });
      items.push({ label: 'Reject Rider', danger: true });
    } else if (rider.status !== 'SUSPENDED') {
      items.push({ label: 'Suspend Rider', danger: true });
    } else {
      items.push({ label: 'Activate Rider' });
    }
    return items;
  }

  protected handleMenuAction(label: string, rider: Rider): void {
    if (label === 'View Detail') {
      this.openRider(rider.id);
    } else if (label === 'Approve Rider') {
      this.approve(rider);
    } else if (label === 'Reject Rider') {
      this.rejectTarget.set(rider);
      this.rejectReason.setValue('');
    } else if (label === 'Suspend Rider') {
      this.suspendTarget.set(rider);
    } else if (label === 'Activate Rider') {
      this.riderService.activate(rider.id).subscribe({
        next: () => {
          this.toastService.show('Rider activated');
          this.riderService.load();
        },
        error: () => this.toastService.show('Unable to activate rider', 'error'),
      });
    }
  }

  private approve(rider: Rider): void {
    this.riderService.approve(rider.id).subscribe({
      next: () => {
        this.toastService.show('Rider approved');
        this.riderService.load();
      },
      error: () => this.toastService.show('Unable to approve rider', 'error'),
    });
  }

  protected confirmSuspend(): void {
    const rider = this.suspendTarget();
    if (!rider) return;
    this.suspending.set(true);
    this.riderService.suspend(rider.id).subscribe({
      next: () => {
        this.suspending.set(false);
        this.suspendTarget.set(null);
        this.toastService.show('Rider suspended');
        this.riderService.load();
      },
      error: () => {
        this.suspending.set(false);
        this.toastService.show('Unable to suspend rider', 'error');
      },
    });
  }

  protected confirmReject(): void {
    const rider = this.rejectTarget();
    if (!rider) return;
    this.rejecting.set(true);
    this.riderService.reject(rider.id, this.rejectReason.value ?? '').subscribe({
      next: () => {
        this.rejecting.set(false);
        this.rejectTarget.set(null);
        this.toastService.show('Rider rejected');
        this.riderService.load();
      },
      error: () => {
        this.rejecting.set(false);
        this.toastService.show('Unable to reject rider', 'error');
      },
    });
  }
}