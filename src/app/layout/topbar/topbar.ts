import { Component, output, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { EchoService } from '../../core/echo/echo.service';

@Component({
  selector: 'app-topbar',
  standalone: true,
  imports: [DatePipe],
  templateUrl: './topbar.html',
  styleUrl: './topbar.css',
})
export class TopbarComponent {
  menuToggle = output<void>();
  sidebarToggle = output<void>();

  private router = inject(Router);
  private authService = inject(AuthService);
  private echoService = inject(EchoService);

  protected readonly user = this.authService.user;
  protected readonly profileOpen = signal(false);
  protected readonly notificationsOpen = signal(false);
  protected readonly pageTitle = 'TalaDelivery';

  protected readonly notifications = this.echoService.notifications$;
  protected readonly unreadCount = this.echoService.unreadCount$;
  protected readonly loadingNotifications = this.echoService.loadingNotifications;

  constructor() {
    this.echoService.connect();
  }

  protected toggleProfile(): void {
    this.profileOpen.update((v) => !v);
    this.notificationsOpen.set(false);
  }

  protected toggleNotifications(): void {
    this.notificationsOpen.update((v) => !v);
    this.profileOpen.set(false);
    if (this.notificationsOpen()) {
      this.echoService.markAllRead();
    }
  }

  protected logout(): void {
    this.echoService.disconnect();
    this.authService.logout();
  }

  protected goTo(route: string): void {
    this.profileOpen.set(false);
    this.router.navigate([route]);
  }
}