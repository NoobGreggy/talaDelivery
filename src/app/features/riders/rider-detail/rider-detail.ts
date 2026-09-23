import { Component, inject, signal, DestroyRef } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { RiderService } from '../../../core/services/rider.service';
import { ToastService } from '../../../core/services/toast.service';
import { ButtonComponent } from '../../../shared/components/button/button';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { AvatarComponent } from '../../../shared/components/avatar/avatar';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { CardComponent } from '../../../shared/components/card/card';
import { Rider } from '../../../core/models';

@Component({
  selector: 'app-rider-detail',
  standalone: true,
  imports: [
    DatePipe,
    CurrencyPipe,
    RouterLink,
    ButtonComponent,
    StatusBadgeComponent,
    AvatarComponent,
    SkeletonComponent,
    ErrorStateComponent,
    EmptyStateComponent,
    ConfirmDialogComponent,
    CardComponent,
  ],
  templateUrl: './rider-detail.html',
  styleUrl: './rider-detail.css',
})
export class RiderDetailComponent {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private riderService = inject(RiderService);
  private toastService = inject(ToastService);
  private destroyRef = inject(DestroyRef);

  protected readonly rider = signal<Rider | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);

  protected readonly suspendDialogOpen = signal(false);
  protected readonly acting = signal(false);

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.loadRider(id);
    });
    this.destroyRef.onDestroy(() => sub.unsubscribe());
  }

  private loadRider(id: number): void {
    this.loading.set(true);
    this.error.set(null);

    this.riderService.getRider(id).subscribe({
      next: (rider) => {
        this.rider.set(rider);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('We couldn\'t load this rider.');
        this.loading.set(false);
      },
    });
  }

  protected retry(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loadRider(id);
  }

  protected goBack(): void {
    this.router.navigate(['/riders']);
  }

  protected toggleStatus(): void {
    const rider = this.rider();
    if (!rider) return;

    const action =
      rider.status === 'SUSPENDED'
        ? this.riderService.activate(rider.id)
        : this.riderService.suspend(rider.id);

    this.acting.set(true);
    action.subscribe({
      next: (updated) => {
        this.rider.set(updated);
        this.suspendDialogOpen.set(false);
        this.acting.set(false);
        this.toastService.show(
          updated.status === 'SUSPENDED' ? 'Rider suspended' : 'Rider activated',
        );
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to update rider', 'error');
      },
    });
  }
}