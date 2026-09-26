import { Component, inject, signal, computed, DestroyRef } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { DeliveryService } from '../../../core/services/delivery.service';
import { RiderService } from '../../../core/services/rider.service';
import { ToastService } from '../../../core/services/toast.service';
import { ButtonComponent } from '../../../shared/components/button/button';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { TimelineComponent } from '../../../shared/components/timeline/timeline';
import { DrawerComponent } from '../../../shared/components/drawer/drawer';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { AvatarComponent } from '../../../shared/components/avatar/avatar';
import { CardComponent } from '../../../shared/components/card/card';
import { Delivery, DeliveryEvent, Rider, RiderLocationEvent } from '../../../core/models';
import { EchoService } from '../../../core/echo/echo.service';
import { DeliveryTrackingMapComponent } from '../delivery-tracking-map/delivery-tracking-map';

@Component({
  selector: 'app-delivery-detail',
  standalone: true,
  imports: [
    DatePipe,
    CurrencyPipe,
    RouterLink,
    ButtonComponent,
    StatusBadgeComponent,
    TimelineComponent,
    DrawerComponent,
    ConfirmDialogComponent,
    ErrorStateComponent,
    SkeletonComponent,
    AvatarComponent,
    CardComponent,
    DeliveryTrackingMapComponent,
  ],
  templateUrl: './delivery-detail.html',
  styleUrl: './delivery-detail.css',
})
export class DeliveryDetailComponent {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private deliveryService = inject(DeliveryService);
  private riderService = inject(RiderService);
  private toastService = inject(ToastService);
  private destroyRef = inject(DestroyRef);
  private echoService = inject(EchoService);
  private stopLocationTracking: (() => void) | null = null;

  protected readonly delivery = signal<Delivery | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);

  protected readonly assignDrawerOpen = signal(false);
  protected readonly cancelDialogOpen = signal(false);
  protected readonly assigningRider = signal(false);
  protected readonly selectedRiderId = signal<number | null>(null);

  protected readonly riders = this.riderService.riders;
  protected readonly ridersLoading = this.riderService.loading;

  protected readonly timelineEvents = computed<DeliveryEvent[]>(() => {
    const delivery = this.delivery();
    if (!delivery) return [];

    if (delivery.timeline && delivery.timeline.length > 0) {
      return delivery.timeline;
    }

    const status = delivery.status;
    const steps = [
      { key: 'CREATED', label: 'Order Created' },
      { key: 'CONFIRMED', label: 'Store Confirmed' },
      { key: 'PREPARING', label: 'Preparing' },
      { key: 'READY', label: 'Ready' },
      { key: 'FINDING_RIDER', label: 'Finding Rider' },
      { key: 'RIDER_ASSIGNED', label: 'Rider Assigned' },
      { key: 'PICKED_UP', label: 'Picked Up' },
      { key: 'OUT_FOR_DELIVERY', label: 'Out for Delivery' },
      { key: 'DELIVERED', label: 'Delivered' },
    ];

    const statusIndex = steps.findIndex((s) => s.key === status);

    return steps.map((step, i) => ({
      label: step.label,
      active: i === statusIndex && status !== 'FAILED' && status !== 'CANCELLED',
      completed: i < statusIndex,
    }));
  });

  protected readonly statusLabel = computed(
    () =>
      this.delivery()
        ?.status?.replace(/_/g, ' ')
        .toLowerCase()
        .replace(/\b\w/g, (c: string) => c.toUpperCase()) ?? '',
  );

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.loadDelivery(id);
    });
    this.destroyRef.onDestroy(() => {
      sub.unsubscribe();
      this.stopLocationTracking?.();
    });
  }

  private loadDelivery(id: number): void {
    this.loading.set(true);
    this.error.set(null);

    this.deliveryService.getDelivery(id).subscribe({
      next: (delivery) => {
        this.delivery.set(delivery);
        this.startLocationTracking(delivery);
        this.loading.set(false);
        this.checkQueryParams();
      },
      error: () => {
        this.error.set("We couldn't load this delivery.");
        this.loading.set(false);
      },
    });
  }

  private startLocationTracking(delivery: Delivery): void {
    this.stopLocationTracking?.();
    this.stopLocationTracking = null;
    if (!['ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'IN_TRANSIT'].includes(delivery.status)) {
      return;
    }
    this.stopLocationTracking = this.echoService.listenToDeliveryLocation(
      delivery.id,
      (location: RiderLocationEvent) => {
        if (location.delivery_id !== delivery.id) return;
        this.delivery.update((current) =>
          current
            ? {
                ...current,
                rider_location: {
                  latitude: location.latitude,
                  longitude: location.longitude,
                  accuracy_m: location.accuracy_m,
                  heading_deg: location.heading_deg,
                  speed_mps: location.speed_mps,
                  recorded_at: location.recorded_at,
                },
              }
            : current,
        );
      },
    );
  }

  protected retry(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loadDelivery(id);
  }

  private checkQueryParams(): void {
    const assign = this.route.snapshot.queryParamMap.get('assign');
    const cancel = this.route.snapshot.queryParamMap.get('cancel');
    if (assign === '1') this.assignDrawerOpen.set(true);
    if (cancel === '1') this.cancelDialogOpen.set(true);
  }

  protected openAssignDrawer(): void {
    this.assignDrawerOpen.set(true);
    this.riderService.loadAvailable();
  }

  protected closeAssignDrawer(): void {
    this.assignDrawerOpen.set(false);
    this.selectedRiderId.set(null);
  }

  protected selectRider(rider: Rider): void {
    this.selectedRiderId.update((current) => (current === rider.id ? null : rider.id));
  }

  protected assignRider(): void {
    const delivery = this.delivery();
    const riderId = this.selectedRiderId();
    if (!delivery || !riderId) return;

    this.assigningRider.set(true);
    this.deliveryService.assignRider(delivery.id, riderId).subscribe({
      next: (updated) => {
        this.delivery.set(updated);
        this.assigningRider.set(false);
        this.closeAssignDrawer();
        this.toastService.show('Rider assigned successfully');
      },
      error: () => {
        this.assigningRider.set(false);
        this.toastService.show('Unable to assign rider', 'error');
      },
    });
  }

  protected openCancelDialog(): void {
    this.cancelDialogOpen.set(true);
  }

  protected cancelDelivery(): void {
    const delivery = this.delivery();
    if (!delivery) return;

    this.deliveryService.cancelDelivery(delivery.id).subscribe({
      next: (updated) => {
        this.delivery.set(updated);
        this.cancelDialogOpen.set(false);
        this.toastService.show('Delivery cancelled');
      },
      error: () => {
        this.toastService.show('Unable to cancel delivery', 'error');
      },
    });
  }

  protected goBack(): void {
    this.router.navigate(['/deliveries']);
  }
}
