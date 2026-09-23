import { Component, computed, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { DashboardService } from '../../../core/services/dashboard.service';
import { StatCardComponent } from '../../../shared/components/stat-card/stat-card';
import { ButtonComponent } from '../../../shared/components/button/button';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { CardComponent } from '../../../shared/components/card/card';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';

@Component({
  selector: 'app-dashboard-page',
  standalone: true,
  imports: [
    RouterLink,
    StatCardComponent,
    ButtonComponent,
    StatusBadgeComponent,
    CardComponent,
    SkeletonComponent,
    ErrorStateComponent,
    EmptyStateComponent,
  ],
  templateUrl: './dashboard-page.html',
  styleUrl: './dashboard-page.css',
})
export class DashboardPageComponent {
  private authService = inject(AuthService);
  private dashboardService = inject(DashboardService);
  private router = inject(Router);

  protected readonly data = this.dashboardService.data;
  protected readonly loading = this.dashboardService.loading;
  protected readonly error = this.dashboardService.error;

  protected readonly greeting = computed(() => {
    const hour = new Date().getHours();
    let greeting = 'Good evening';
    if (hour < 12) greeting = 'Good morning';
    else if (hour < 18) greeting = 'Good afternoon';
    const name = this.authService.user()?.name?.split(' ')[0];
    return `${greeting}${name ? ', ' + name : ''}`;
  });

  constructor() {
    this.dashboardService.load();
  }

  protected retry(): void {
    this.dashboardService.load();
  }

  protected formatTime(iso: string | undefined): string {
    if (!iso) return '';
    const d = new Date(iso);
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
}