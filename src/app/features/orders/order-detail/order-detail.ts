import { Component, inject, signal, DestroyRef, effect } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { DatePipe, CurrencyPipe } from '@angular/common';
import { StoreOrderService } from '../../../core/services/store-order.service';
import { ToastService } from '../../../core/services/toast.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { CardComponent } from '../../../shared/components/card/card';
import { Order } from '../../../core/models';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { EchoService } from '../../../core/echo/echo.service';

@Component({
  selector: 'app-order-detail',
  standalone: true,
  imports: [
    DatePipe,
    CurrencyPipe,
    StatusBadgeComponent,
    ButtonComponent,
    ErrorStateComponent,
    CardComponent,
    ModalComponent,
  ],
  templateUrl: './order-detail.html',
  styleUrl: './order-detail.css',
})
export class OrderDetailComponent {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private orderService = inject(StoreOrderService);
  private toastService = inject(ToastService);
  private echoService = inject(EchoService);
  private destroyRef = inject(DestroyRef);

  protected readonly order = signal<Order | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);
  protected readonly acting = signal(false);

  protected readonly cancelTarget = signal<Order | null>(null);
  protected readonly cancelReason = signal('');

  constructor() {
    const sub = this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('id'));
      this.loadOrder(id);
    });
    this.destroyRef.onDestroy(() => sub.unsubscribe());

    effect(() => {
      const update = this.echoService.orderUpdated$();
      const current = this.order();
      if (update && current && update.id === current.id) {
        this.loadOrder(update.id);
      }
    });
  }

  private loadOrder(id: number): void {
    this.loading.set(true);
    this.error.set(null);

    this.orderService.getOrder(id).subscribe({
      next: (order) => {
        this.order.set(order);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('We couldn\'t load this order.');
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

  protected canAct(order: Order): { label: string; action: () => void; danger?: boolean; disabled?: boolean }[] {
    const actions: { label: string; action: () => void; danger?: boolean; disabled?: boolean }[] = [];
    switch (order.status) {
      case 'PENDING':
        actions.push({ label: 'Confirm Order', action: () => this.transition('confirm') });
        actions.push({ label: 'Cancel Order', action: () => this.openCancel(), danger: true });
        break;
      case 'CONFIRMED':
        actions.push({ label: 'Start Preparing', action: () => this.transition('preparing') });
        actions.push({ label: 'Cancel Order', action: () => this.openCancel(), danger: true });
        break;
      case 'PREPARING':
        actions.push({ label: 'Mark Ready', action: () => this.transition('ready') });
        actions.push({ label: 'Cancel Order', action: () => this.openCancel(), danger: true });
        break;
      default:
        break;
    }
    return actions;
  }

  protected itemSubtotal(item: { quantity: number; price: number }): number {
    return item.quantity * item.price;
  }

  private transition(action: 'confirm' | 'preparing' | 'ready'): void {
    const current = this.order();
    if (!current) return;

    this.acting.set(true);
    const request =
      action === 'confirm'
        ? this.orderService.confirm(current.id)
        : action === 'preparing'
          ? this.orderService.preparing(current.id)
          : this.orderService.ready(current.id);

    request.subscribe({
      next: (updated) => {
        this.order.set(updated);
        this.acting.set(false);
        this.toastService.show('Order updated');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to update order', 'error');
      },
    });
  }

  protected openCancel(): void {
    this.cancelTarget.set(this.order());
    this.cancelReason.set('');
  }

  protected confirmCancel(): void {
    const order = this.cancelTarget();
    if (!order) return;

    this.acting.set(true);
    this.orderService.cancel(order.id, this.cancelReason()).subscribe({
      next: (updated) => {
        this.order.set(updated);
        this.cancelTarget.set(null);
        this.acting.set(false);
        this.toastService.show('Order cancelled');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to cancel order', 'error');
      },
    });
  }

  protected setCancelReason(value: string): void {
    this.cancelReason.set(value);
  }
}