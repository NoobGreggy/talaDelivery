import { Component, inject, signal, DestroyRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { debounceTime, fromEvent, interval, merge, Subscription } from 'rxjs';
import { RealtimeService } from '../../../core/realtime/realtime.service';
import { ActivatedRoute, Router } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { OrderService } from '../../../core/services/order.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { CardComponent } from '../../../shared/components/card/card';
import { Order } from '../../../core/models';

@Component({
  selector: 'app-order-detail',
  standalone: true,
  imports: [
    DatePipe,
    CurrencyPipe,
    StatusBadgeComponent,
    SkeletonComponent,
    ErrorStateComponent,
    CardComponent,
  ],
  templateUrl: './order-detail.html',
  styleUrl: './order-detail.css',
})
export class OrderDetailComponent {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private orderService = inject(OrderService);
  private destroyRef = inject(DestroyRef);
  private realtime = inject(RealtimeService);
  private request?: Subscription;

  protected readonly order = signal<Order | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.loadOrder(id);
    });
    this.destroyRef.onDestroy(() => { sub.unsubscribe(); this.request?.unsubscribe(); });
    this.realtime.connect();
    merge(this.realtime.orderUpdated$, fromEvent(window, 'focus')).pipe(debounceTime(250), takeUntilDestroyed())
      .subscribe((event) => {
        const id = Number(this.route.snapshot.paramMap.get('id'));
        if (!('orderId' in event) || event.orderId === id) this.loadOrder(id, true);
      });
    interval(10000).pipe(takeUntilDestroyed()).subscribe(() => {
      if (!document.hidden) this.loadOrder(Number(this.route.snapshot.paramMap.get('id')), true);
    });
  }

  private loadOrder(id: number, silent = false): void {
    this.request?.unsubscribe();
    this.loading.set(!silent);
    if (!silent) { this.error.set(null); this.order.set(null); }

    this.request = this.orderService.getOrder(id).subscribe({
      next: (order) => {
        this.order.set(order);
        this.loading.set(false);
        this.error.set(null);
      },
      error: () => {
        this.error.set(silent ? 'Order updates are temporarily unavailable. Retry to reconnect.' : 'We couldn\'t load this order.');
        this.loading.set(false);
      },
    });
  }

  protected retry(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loadOrder(id);
  }

  protected goBack(): void {
    this.router.navigate(['/orders']);
  }
}
