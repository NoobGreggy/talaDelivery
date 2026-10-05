import { Injectable, inject, signal } from '@angular/core';
import { Subject } from 'rxjs';
import { io, type Socket } from 'socket.io-client';
import { environment } from '../../../environments/environment';
import { AuthService } from '../auth/auth.service';
import { ToastService } from '../services/toast.service';
import {
  OrderUpdatedRealtimeEvent,
  RealtimeStatus,
  RiderApplicationRealtimeEvent,
  RiderLocationRealtimeEvent,
} from '../models';

/**
 * Socket.IO connection to the NestJS realtime gateway (`/realtime` namespace).
 *
 * Replaces the Laravel Echo/Pusher path for the NestJS backend. The gateway
 * authorizes rooms at subscribe time, so this service only decides *which*
 * rooms to ask for and turns the resulting events into signals.
 *
 * Socket lifecycle notes:
 *  - `connect()` is idempotent and safe to call from a component constructor.
 *  - Room subscriptions are re-issued on every `connect` event, because the
 *    server has no memory of them across a reconnect.
 *  - The token is read at connect time; on logout the socket is torn down so a
 *    refresh cannot reuse the previous identity.
 */
@Injectable({ providedIn: 'root' })
export class RealtimeService {
  private authService = inject(AuthService);
  private toast = inject(ToastService);

  private socket: Socket | null = null;
  private readonly statusSignal = signal<RealtimeStatus>('disconnected');

  private readonly orderUpdatedSubject = new Subject<OrderUpdatedRealtimeEvent>();
  private readonly riderApplicationSubject = new Subject<RiderApplicationRealtimeEvent>();
  private readonly riderLocationSubject = new Subject<RiderLocationRealtimeEvent>();

  readonly status = this.statusSignal.asReadonly();
  readonly orderUpdated$ = this.orderUpdatedSubject.asObservable();
  readonly riderApplication$ = this.riderApplicationSubject.asObservable();
  readonly riderLocation$ = this.riderLocationSubject.asObservable();

  connect(): void {
    if (this.socket) return;

    const token = this.authService.getToken();
    if (!token) return;

    this.statusSignal.set('connecting');

    // socket.io-client takes the namespace as a path segment of the URL; there
    // is no `namespace` option. The dev proxy forwards `/socket.io/**` to the
    // realtime service, so the handshake stays same-origin.
    const origin = environment.socketIo.url ?? window.location.origin;
    this.socket = io(`${origin.replace(/\/$/, '')}/realtime`, {
      path: environment.socketIo.path,
      transports: ['websocket', 'polling'],
      auth: { token },
      reconnectionAttempts: 10,
      reconnectionDelay: 2000,
    });

    this.socket.on('connect', () => {
      this.statusSignal.set('connected');
      this.subscribeRooms();
    });

    this.socket.on('disconnect', () => this.statusSignal.set('disconnected'));
    this.socket.on('connect_error', () => this.statusSignal.set('error'));

    this.socket.on('rider.application', (payload: RiderApplicationRealtimeEvent) => {
      this.riderApplicationSubject.next(payload);
      this.toast.show(`New rider application from ${payload.name}`, 'info');
    });

    this.socket.on('order.updated', (payload: OrderUpdatedRealtimeEvent) => {
      this.orderUpdatedSubject.next(payload);
    });

    this.socket.on('rider.location', (payload: RiderLocationRealtimeEvent) => {
      this.riderLocationSubject.next(payload);
    });
  }

  disconnect(): void {
    this.socket?.removeAllListeners();
    this.socket?.disconnect();
    this.socket = null;
    this.statusSignal.set('disconnected');
  }

  /**
   * Reconnect with a fresh token. Called after login and after a token
   * refresh, because the gateway verifies the token on connect.
   */
  reconnect(): void {
    this.disconnect();
    this.connect();
  }

  /**
   * Follow a single delivery's rider position.
   *
   * The gateway authorizes `order:<deliveryId>` for any authenticated user, so
   * this is only a routing decision. Returns an unsubscribe function.
   */
  watchDelivery(
    deliveryId: number,
    onLocation: (location: RiderLocationRealtimeEvent) => void,
  ): () => void {
    this.connect();
    const socket = this.socket;
    if (!socket) return () => undefined;

    const handler = (payload: RiderLocationRealtimeEvent) => {
      if (payload.deliveryId === deliveryId) onLocation(payload);
    };
    const subscription = this.riderLocationSubject.subscribe(handler);
    socket.emit('subscribe', { room: `order:${deliveryId}` });

    return () => {
      subscription.unsubscribe();
      socket.emit('unsubscribe', { room: `order:${deliveryId}` });
    };
  }

  private subscribeRooms(): void {
    const user = this.authService.user();
    if (!user || !this.socket) return;

    this.socket.emit('subscribe', { room: 'admin:platform' });
    this.socket.emit('subscribe', { room: `user:${user.id}` });
  }
}
