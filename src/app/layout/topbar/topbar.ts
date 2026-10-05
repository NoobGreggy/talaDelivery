import { Component, output, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { RealtimeService } from '../../core/realtime/realtime.service';
import { NotificationService } from '../../core/services/notification.service';

@Component({
  selector: 'app-topbar',
  standalone: true,
  imports: [DatePipe],
  templateUrl: './topbar.html',
  styleUrl: './topbar.css',
})
export class TopbarComponent {
  menuToggle = output<void>();

  private router = inject(Router);
  private authService = inject(AuthService);
  private realtime = inject(RealtimeService);
  private notificationService = inject(NotificationService);

  protected readonly user = this.authService.user;
  protected readonly profileOpen = signal(false);
  protected readonly notificationsOpen = signal(false);
  protected readonly notifications = this.notificationService.items;
  protected readonly unreadCount = this.notificationService.unreadCount;
  protected readonly loadingNotifications = this.notificationService.loading;

  constructor() {
    this.realtime.connect();
    this.notificationService.load();
  }

  protected toggleProfile(): void {
    this.profileOpen.update((v) => !v);
    this.notificationsOpen.set(false);
  }

  protected toggleNotifications(): void {
    this.notificationsOpen.update((v) => !v);
    this.profileOpen.set(false);
    if (this.notificationsOpen()) {
      this.notificationService.markAllRead();
    }
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
