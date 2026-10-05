import { Injectable, inject, signal } from '@angular/core';
import { io, Socket } from 'socket.io-client';
import { environment } from '../../../environments/environment';
import { AuthService } from '../auth/auth.service';
import { NotificationService } from '../services/notification.service';
import { OrderUpdatedRealtimeEvent, RealtimeStatus } from '../models';

/** Store lifecycle updates from the NestJS Socket.IO gateway. */
@Injectable({ providedIn: 'root' })
export class RealtimeService {
  private auth = inject(AuthService);
  private notifications = inject(NotificationService);
  private socket: Socket | null = null;
  private statusSignal = signal<RealtimeStatus>('disconnected');
  private orderSignal = signal<OrderUpdatedRealtimeEvent | null>(null);
  private versionSignal = signal(0);
  readonly status = this.statusSignal.asReadonly();
  readonly orderUpdated = this.orderSignal.asReadonly();
  readonly connectionVersion = this.versionSignal.asReadonly();

  connect(): void {
    if (this.socket || !this.auth.getToken()) return;
    this.statusSignal.set('connecting');
    const origin = environment.socketIo.url ?? window.location.origin;
    const socket = this.socket = io(`${origin.replace(/\/$/, '')}/realtime`, {
      path: environment.socketIo.path, auth: { token: this.auth.getToken() },
      transports: ['websocket', 'polling'], reconnectionDelay: 2000,
    });
    socket.on('connect', () => {
      const storeIds = new Set((this.auth.user()?.stores ?? []).map((store) => store.id));
      const selected = this.auth.getStoreId();
      if (selected) storeIds.add(selected);
      socket.emit('subscribe', { room: `user:${this.auth.user()?.id}` });
      for (const id of storeIds) {
        socket.emit('subscribe', { room: `merchant:${id}` }, (reply: { success: boolean; data?: { success: boolean } }) => {
          const result = reply?.data ?? reply;
          if (!result?.success) { this.statusSignal.set('error'); return; }
          this.statusSignal.set('connected');
          this.versionSignal.update((version) => version + 1);
        });
      }
      this.notifications.load();
    });
    socket.on('disconnect', () => this.statusSignal.set('disconnected'));
    socket.on('connect_error', () => this.statusSignal.set('error'));
    socket.on('order.updated', (event: OrderUpdatedRealtimeEvent) => {
      this.orderSignal.set(event);
      this.notifications.load();
    });
    socket.on('notification.created', () => this.notifications.load());
  }

  disconnect(): void {
    this.socket?.removeAllListeners();
    this.socket?.disconnect();
    this.socket = null;
    this.orderSignal.set(null);
    this.statusSignal.set('disconnected');
  }
}
