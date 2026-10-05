import { Injectable, computed, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { AppNotification, PaginatedResponse } from '../models';
import { Subscription } from 'rxjs';

/** `meta` carries the extra counters the store-scoped feed returns. */
export type StoreNotificationPage = PaginatedResponse<AppNotification> & {
  meta: PaginatedResponse<AppNotification>['meta'] & {
    unread?: number;
    store?: { id: number; name: string | null };
  };
};

/**
 * Notification feed for the merchant console.
 *
 * Reads the caller's persisted `/notifications` feed. Read/unread mutations
 * use the same per-user scope, so another member's notifications are untouched.
 *
 * Realtime updates are pushed in by `RealtimeService`; this service owns the
 * persisted state and the read/unread transitions.
 */
@Injectable({ providedIn: 'root' })
export class NotificationService {
  private request?: Subscription;
  private api = inject(ApiClientService);

  private readonly itemsSignal = signal<AppNotification[]>([]);
  private readonly unreadSignal = signal(0);
  private readonly loadingSignal = signal(false);
  private readonly storeSignal = signal<{ id: number; name: string | null } | null>(null);

  readonly items = this.itemsSignal.asReadonly();
  readonly unreadCount = this.unreadSignal.asReadonly();
  readonly loading = this.loadingSignal.asReadonly();
  readonly store = this.storeSignal.asReadonly();
  readonly hasUnread = computed(() => this.unreadSignal() > 0);

  load(perPage = 20): void {
    this.request?.unsubscribe();
    this.loadingSignal.set(true);
    this.request = this.api
      .get<StoreNotificationPage>('/notifications', { per_page: String(perPage) })
      .subscribe({
        next: (page) => {
          this.itemsSignal.set(page.data);
          this.unreadSignal.set(page.meta.unread ?? page.data.filter((n) => !n.is_read).length);
          this.storeSignal.set(page.meta.store ?? null);
          this.loadingSignal.set(false);
        },
        error: () => this.loadingSignal.set(false),
      });
  }

  /**
   * Fold a realtime event into the feed.
   *
   * The row only exists once notification-service has persisted it, so this
   * prepends a provisional entry replaced by the next `load()`.
   */
  pushOptimistic(input: {
    title: string;
    body: string;
    type: string;
    data: Record<string, unknown>;
  }): void {
    const now = new Date().toISOString();
    const provisional: AppNotification = {
      id: -Date.now(),
      type: input.type,
      title: input.title,
      body: input.body,
      data: input.data,
      is_read: false,
      read_at: null,
      sent_at: now,
      created_at: now,
    };
    this.itemsSignal.update((current) => [provisional, ...current].slice(0, 50));
    this.unreadSignal.update((count) => count + 1);
  }

  markAsRead(id: number): void {
    // Provisional entries have no server id yet, so settle them locally.
    if (id < 0) {
      this.applyLocalRead(id);
      return;
    }
    this.api.post(`/notifications/${id}/read`).subscribe({
      next: () => this.applyLocalRead(id),
      error: () => undefined,
    });
  }

  markAllRead(): void {
    if (this.unreadSignal() === 0) return;
    this.api.post('/notifications/read-all').subscribe({
      next: () => {
        const now = new Date().toISOString();
        this.itemsSignal.update((current) =>
          current.map((n) => (n.is_read ? n : { ...n, is_read: true, read_at: now })),
        );
        this.unreadSignal.set(0);
      },
      error: () => undefined,
    });
  }

  clear(): void {
    this.request?.unsubscribe();
    this.itemsSignal.set([]);
    this.unreadSignal.set(0);
    this.storeSignal.set(null);
  }

  private applyLocalRead(id: number): void {
    if (!this.itemsSignal().some((item) => item.id === id && !item.is_read)) return;
    const now = new Date().toISOString();
    this.itemsSignal.update((current) =>
      current.map((n) => (n.id === id && !n.is_read ? { ...n, is_read: true, read_at: now } : n)),
    );
    this.unreadSignal.update((count) => Math.max(0, count - 1));
  }
}
