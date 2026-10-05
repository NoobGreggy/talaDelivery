import { Component, inject, signal, DestroyRef } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DatePipe, CurrencyPipe, DecimalPipe } from '@angular/common';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { RiderService } from '../../../core/services/rider.service';
import { ToastService } from '../../../core/services/toast.service';
import { ButtonComponent } from '../../../shared/components/button/button';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { AvatarComponent } from '../../../shared/components/avatar/avatar';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { CardComponent } from '../../../shared/components/card/card';
import { Rider, RiderCoinTransaction } from '../../../core/models';

@Component({
  selector: 'app-rider-detail',
  standalone: true,
  imports: [
    DatePipe,
    DecimalPipe,
    CurrencyPipe,
    RouterLink,
    ReactiveFormsModule,
    ButtonComponent,
    StatusBadgeComponent,
    AvatarComponent,
    SkeletonComponent,
    ErrorStateComponent,
    EmptyStateComponent,
    ConfirmDialogComponent,
    ModalComponent,
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
  protected readonly coinHistory = signal<RiderCoinTransaction[]>([]);
  protected readonly coinsLoading = signal(false);
  protected readonly coinsError = signal<string | null>(null);
  protected readonly coinsPage = signal(1);
  protected readonly coinsLastPage = signal(1);
  protected readonly topUpOpen = signal(false);
  protected readonly toppingUp = signal(false);
  protected readonly topUpError = signal<string | null>(null);
  protected readonly topUpAmount = new FormControl<number | null>(null, [Validators.required, Validators.min(0.01), Validators.max(99999999.99), Validators.pattern(/^\d+(\.\d{1,2})?$/)]);
  protected readonly topUpNote = new FormControl('', Validators.maxLength(500));
  private topUpRequest: { payload: string; id: string } | null = null;
  private historyRequest = 0;

  // Approving an application is the reason an admin opens this page, so the
  // decision lives here too — it used to be reachable only from the list page
  // dropdown, which left a pending rider looking un-actionable.
  protected readonly rejectDialogOpen = signal(false);
  protected readonly rejectReason = new FormControl('');

  protected readonly isPending = () => this.rider()?.status === 'PENDING';

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
    this.rider.set(null);
    this.coinHistory.set([]);

    this.riderService.getRider(id).subscribe({
      next: (rider) => {
        this.rider.set(rider);
        this.loading.set(false);
        this.loadCoins(1);
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

  protected loadCoins(page = this.coinsPage()): void {
    const rider = this.rider();
    if (!rider) return;
    const request = ++this.historyRequest;
    this.coinsLoading.set(true);
    this.coinsError.set(null);
    this.riderService.coinHistory(rider.id, page).subscribe({
      next: (result) => {
        if (request !== this.historyRequest || this.rider()?.id !== rider.id) return;
        this.coinHistory.set(result.data);
        this.coinsPage.set(result.meta.current_page);
        this.coinsLastPage.set(result.meta.last_page);
        this.coinsLoading.set(false);
      },
      error: () => {
        if (request !== this.historyRequest || this.rider()?.id !== rider.id) return;
        this.coinsError.set('Unable to load Tala Coins history.');
        this.coinsLoading.set(false);
      },
    });
  }

  protected openTopUp(): void {
    this.topUpAmount.reset();
    this.topUpNote.reset('');
    this.topUpError.set(null);
    this.topUpRequest = null;
    this.topUpOpen.set(true);
  }

  protected closeTopUp(): void { if (!this.toppingUp()) this.topUpOpen.set(false); }

  protected topUp(): void {
    const rider = this.rider();
    if (!rider || this.toppingUp() || this.topUpAmount.invalid || this.topUpNote.invalid) return;
    const amount = Number(this.topUpAmount.value).toFixed(2);
    const note = this.topUpNote.value?.trim() ?? '';
    const payload = JSON.stringify({ riderId: rider.id, amount, note });
    if (this.topUpRequest?.payload !== payload) this.topUpRequest = { payload, id: crypto.randomUUID() };
    this.toppingUp.set(true);
    this.topUpError.set(null);
    this.riderService.topUpCoins(rider.id, amount, note, this.topUpRequest.id).subscribe({
      next: (updated) => {
        this.toppingUp.set(false);
        this.topUpOpen.set(false);
        if (this.rider()?.id === rider.id) { this.rider.set(updated); this.loadCoins(1); }
        this.toastService.show('Tala Coins added');
      },
      error: (error) => {
        this.toppingUp.set(false);
        this.topUpError.set(error.error?.message ?? 'Unable to add Tala Coins. You can retry this top-up.');
      },
    });
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

  protected approve(): void {
    const rider = this.rider();
    if (!rider) return;

    this.acting.set(true);
    this.riderService.approve(rider.id).subscribe({
      next: (updated) => {
        this.rider.set(updated);
        this.acting.set(false);
        this.toastService.show(`${updated.name || 'Rider'} approved`);
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to approve rider', 'error');
      },
    });
  }

  protected openReject(): void {
    this.rejectReason.setValue('');
    this.rejectDialogOpen.set(true);
  }

  protected confirmReject(): void {
    const rider = this.rider();
    if (!rider) return;

    this.acting.set(true);
    this.riderService.reject(rider.id, this.rejectReason.value ?? '').subscribe({
      next: (updated) => {
        this.rider.set(updated);
        this.acting.set(false);
        this.rejectDialogOpen.set(false);
        this.toastService.show('Rider rejected');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to reject rider', 'error');
      },
    });
  }
}
