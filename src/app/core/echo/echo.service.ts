import { Injectable, inject, signal } from '@angular/core';
import Echo, { BroadcastDriver } from 'laravel-echo';
import Pusher from 'pusher-js';
import { environment } from '../../../environments/environment';
import { ApiClientService } from '../api/api-client.service';
import { AuthService } from '../auth/auth.service';
import { AppNotification } from '../models';

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

  readonly notifications$ = this.notifications.asReadonly();
  readonly unreadCount$ = this.unread.asReadonly();
  readonly loadingNotifications = this.loading.asReadonly();

  connect(): void {
    if (this.echo) return;

    const token = this.authService.getToken();
    const user = this.authService.user();
    if (!token || !user) return;

    this.loadInitialNotifications();

    window.Pusher = Pusher;

    this.echo = new Echo({
      broadcaster: 'reverb',
      key: environment.reverb.appKey,
      wsHost: environment.reverb.host,
      wsPort: environment.reverb.port,
      wrapTLS: false,
      forceTLS: false,
      enabledTransports: ['ws', 'wss'],
      authEndpoint: '/broadcasting/auth',
      auth: {
        headers: {
          Authorization: `Bearer ${token}`,
          'X-App-Key': environment.appKey,
          Accept: 'application/json',
        },
      },
    });

    this.echo
      .private(`user.${user.id}`)
      .listen('.notification.created', (payload: AppNotification) => {
        this.notifications.update((current) => [payload, ...current].slice(0, 50));
        this.unread.update((count) => count + 1);
      });
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