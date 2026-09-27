import { Injectable, inject, signal } from '@angular/core';
import Echo, { BroadcastDriver } from 'laravel-echo';
import Pusher from 'pusher-js';
import { environment } from '../../../environments/environment';
import { ApiClientService } from '../api/api-client.service';
import { AuthService } from '../auth/auth.service';
import { AppNotification } from '../models';

export interface OrderUpdatedPayload {
  id: number;
  order_number: string;
  status: string;
  total: number;
  updated_at: string;
}

declare global {
  interface Window {
    Pusher: typeof Pusher;
  }
}

@Injectable({ providedIn: 'root' })
export class EchoService {
  private authService = inject(AuthService);
  private api = inject(ApiClientService);

  private echo: Echo<BroadcastDriver> | null = null;
  private notifications = signal<AppNotification[]>([]);
  private unread = signal(0);
  private loading = signal(false);
  private orderUpdated = signal<OrderUpdatedPayload | null>(null);
  private connectionVersion = signal(0);

  readonly notifications$ = this.notifications.asReadonly();
  readonly unreadCount$ = this.unread.asReadonly();
  readonly loadingNotifications = this.loading.asReadonly();
  readonly orderUpdated$ = this.orderUpdated.asReadonly();
  readonly connectionVersion$ = this.connectionVersion.asReadonly();

  connect(): void {
    if (this.echo) return;

    const token = this.authService.getToken();
    const user = this.authService.user();
    const storeId = this.authService.getStoreId();
    if (!token || !user) return;

    this.loadInitialNotifications();

    window.Pusher = Pusher;
    const useTls = environment.reverb.scheme === 'https';

    this.echo = new Echo({
      broadcaster: 'reverb',
      key: environment.reverb.appKey,
      wsHost: environment.reverb.host,
      wsPort: environment.reverb.port,
      wssPort: environment.reverb.port,
      wrapTLS: useTls,
      // pusher-js falls back to plain ws:// when the page itself is http:// (the dev
      // server), which this TLS-only Reverb host rejects. forceTLS keeps it on wss://.
      forceTLS: useTls,
      enabledTransports: ['ws', 'wss'],
      authEndpoint: environment.broadcastAuthUrl,
      auth: {
        headers: {
          Authorization: `Bearer ${token}`,
          'X-App-Key': environment.appKey,
          Accept: 'application/json',
        },
      },
    });

    // `PusherConnector` is not exported by laravel-echo, so narrow structurally.
    const pusher = (this.echo.connector as { pusher?: Pusher }).pusher;
    pusher?.connection.bind('connected', () => {
      // Reverb does not replay messages missed while the browser was offline.
      // Consumers use this monotonic version to reconcile from the REST API.
      this.connectionVersion.update((version) => version + 1);
    });
    pusher?.connection.bind('pusher:error', (error: unknown) => {
      console.error('[Echo] Realtime connection error:', error);
    });

    const userChannel = this.echo.private(`user.${user.id}`);
    userChannel
      .listen('.notification.created', (payload: AppNotification) => {
        this.notifications.update((current) => [payload, ...current].slice(0, 50));
        this.unread.update((count) => count + 1);
      })
      .listen('.error', (error: unknown) => {
        // Raised when /broadcasting/auth rejects the subscription (CORS, 401, 403).
        console.error('[Echo] Channel subscription error:', error);
      });

    if (storeId) {
      this.echo
        .private(`store.${storeId}`)
        .listen('.order.updated', (payload: OrderUpdatedPayload) => {
          this.orderUpdated.set(payload);
        });
    }
  }

  disconnect(): void {
    this.echo?.disconnect();
    this.echo = null;
  }

  markAllRead(): void {
    this.unread.set(0);
  }

  private loadInitialNotifications(): void {
    this.loading.set(true);
    this.api
      .get<{ data: AppNotification[]; meta: { total: number } }>('/notifications', { per_page: '10' })
      .subscribe({
        next: (result) => {
          this.notifications.set(result.data);
          this.unread.set(result.data.filter((n) => !n.is_read).length);
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
  }
}
