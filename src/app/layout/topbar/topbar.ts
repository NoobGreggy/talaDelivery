import { Component, output, inject, signal, OnDestroy } from '@angular/core';
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';
import { Subscription, interval } from 'rxjs';
import { AuthService } from '../../core/auth/auth.service';
import { NotificationService } from '../../core/services/notification.service';
import { RealtimeService } from '../../core/realtime/realtime.service';
import { AppNotification } from '../../core/models';

@Component({
  selector: 'app-topbar',
  standalone: true,
  imports: [DatePipe],
  templateUrl: './topbar.html',
  styleUrl: './topbar.css',
})
export class TopbarComponent implements OnDestroy {
  menuToggle = output<void>();
  sidebarToggle = output<void>();

  private router = inject(Router);
  private authService = inject(AuthService);
  private notificationService = inject(NotificationService);
  private realtime = inject(RealtimeService);

  protected readonly user = this.authService.user;
  protected readonly profileOpen = signal(false);
  protected readonly notificationsOpen = signal(false);
  protected readonly pageTitle = 'TalaDelivery';

  protected readonly notifications = this.notificationService.items;
  protected readonly unreadCount = this.notificationService.unreadCount;
  protected readonly loadingNotifications = this.notificationService.loading;
  protected readonly realtimeStatus = this.realtime.status;

  private subscriptions = new Subscription();

  constructor() {
    this.notificationService.load();
    this.subscriptions.add(interval(15000).subscribe(() => this.notificationService.load()));
    this.realtime.connect();

    // A rider application is the one platform event an admin must not miss;
    // the row arrives over the socket, the notification a moment later.
    this.subscriptions.add(
      this.realtime.riderApplication$.subscribe((payload) => {
        this.notificationService.pushOptimistic({
          title: 'New rider application',
          body: `${payload.name} (${payload.email}) applied to ride.`,
          type: 'admin.rider_application',
          data: {
            userId: payload.userId,
            riderId: payload.riderId,
            email: payload.email,
          },
        });
        this.notificationService.load();
      }),
    );

    this.subscriptions.add(
      this.realtime.orderUpdated$.subscribe(() => {
        // Orders move often; refetch the feed rather than tracking each one.
        this.notificationService.load();
      }),
    );
  }

  ngOnDestroy(): void {
    this.subscriptions.unsubscribe();
  }

  protected toggleProfile(): void {
    this.profileOpen.update((v) => !v);
    this.notificationsOpen.set(false);
  }

  protected toggleNotifications(): void {
    this.notificationsOpen.update((v) => !v);
    this.profileOpen.set(false);
    if (this.notificationsOpen()) {
      this.notificationService.load();
    }
  }

  protected markAllRead(): void {
    this.notificationService.markAllRead();
  }

  protected openNotification(notification: AppNotification): void {
    this.notificationService.markAsRead(notification.id);
    this.notificationsOpen.set(false);

    const data = notification.data ?? {};
    if (notification.type === 'admin.rider_coins_negative' && data['riderId']) {
      this.router.navigate(['/riders', data['riderId']]);
      return;
    }
    if (notification.type === 'admin.rider_application' && data['userId']) {
      this.router.navigate(['/riders']);
      return;
    }
    if (data['orderId']) {
      this.router.navigate(['/orders', data['orderId']]);
    }
  }

  protected bodyOf(notification: AppNotification): string {
    return notification.body;
  }

  protected trackById(_index: number, notification: AppNotification): number {
    return notification.id;
  }

  protected isLive(): boolean {
    return this.realtimeStatus() === 'connected';
  }

  protected logout(): void {
    this.realtime.disconnect();
    this.notificationService.clear();
    this.authService.logout();
  }

  protected goTo(route: string): void {
    this.profileOpen.set(false);
    this.router.navigate([route]);
  }
}
