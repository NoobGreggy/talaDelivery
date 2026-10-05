import { Injectable, computed, inject, signal } from '@angular/core';
import { ApiClientService } from '../api/api-client.service';
import { AppNotification, PaginatedResponse } from '../models';

/** `meta` carries extra counters for the scoped feeds. */
export type ScopedNotificationPage = PaginatedResponse<AppNotification> & {
  meta: PaginatedResponse<AppNotification>['meta'] & {
    unread?: number;
    by_type?: Array<{ type: string; count: number }>;
    store?: { id: number; name: string | null };
  };
};

/**
 * Notification feed for the admin console.
 *
 * Reads `GET /admin/notifications` (platform-admin only), which returns the
 * whole platform feed across every admin rather than just the caller's own
 * rows. Scope comes from the token — there is deliberately no parameter to
 * widen it.
 *
 * Realtime updates are pushed in by `RealtimeService`; this service owns the
 * persisted state and the read/unread transitions.
 */
@Injectable({ providedIn: 'root' })
export class NotificationService {
  private api = inject(ApiClientService);

  private readonly itemsSignal = signal<AppNotification[]>([]);
  private readonly unreadSignal = signal(0);
  private readonly loadingSignal = signal(false);
  private readonly byTypeSignal = signal<Array<{ type: string; count: number }>>([]);

  readonly items = this.itemsSignal.asReadonly();
  readonly unreadCount = this.unreadSignal.asReadonly();
  readonly loading = this.loadingSignal.asReadonly();
  readonly byType = this.byTypeSignal.asReadonly();
  readonly hasUnread = computed(() => this.unreadSignal() > 0);

  load(perPage = 20): void {
    this.loadingSignal.set(true);
    this.api
      .get<ScopedNotificationPage>('/admin/notifications', { per_page: String(perPage) })
      .subscribe({
        next: (page) => {
          this.itemsSignal.set(page.data);
          this.unreadSignal.set(page.meta.unread ?? page.data.filter((n) => !n.is_read).length);
          this.byTypeSignal.set(page.meta.by_type ?? []);
          this.loadingSignal.set(false);
        },
        error: () => this.loadingSignal.set(false),
      });
  }

  /**
   * Fold a realtime event into the feed.
   *
   * The gateway emits `rider.application`; the row itself only exists once the
   * consumer has persisted it, so this prepends a provisional entry that is
   * replaced by the next `load()`.
   */
  pushOptimistic(input: {
    title: string;
    body: string;
    type: string;
    data: Record<string, unknown>;
  }): void {
    const provisional: AppNotification = {
      id: -Date.now(),
      type: input.type,
      title: input.title,
      body: input.body,
      data: input.data,
      is_read: false,
      read_at: null,
      sent_at: new Date().toISOString(),
      created_at: new Date().toISOString(),
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
    this.itemsSignal.set([]);
    this.unreadSignal.set(0);
    this.byTypeSignal.set([]);
  }

  private applyLocalRead(id: number): void {
    const now = new Date().toISOString();
    this.itemsSignal.update((current) =>
      current.map((n) => (n.id === id && !n.is_read ? { ...n, is_read: true, read_at: now } : n)),
    );
    this.unreadSignal.update((count) => Math.max(0, count - 1));
  }
}
