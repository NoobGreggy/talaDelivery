import { Component, computed, inject } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { DashboardService } from '../../../core/services/dashboard.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';
import { SkeletonComponent } from '../../../shared/components/skeleton/skeleton';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';

@Component({
  selector: 'app-dashboard-page', standalone: true,
  imports: [RouterLink, DecimalPipe, StatusBadgeComponent, SkeletonComponent, ErrorStateComponent],
  templateUrl: './dashboard-page.html', styleUrl: './dashboard-page.css',
})
export class DashboardPageComponent {
  private authService = inject(AuthService);
  private dashboardService = inject(DashboardService);
  protected readonly isPlatformAdmin = this.authService.isPlatformAdmin;
  protected readonly data = this.dashboardService.data;
  protected readonly loading = this.dashboardService.loading;
  protected readonly error = this.dashboardService.error;
  protected readonly greeting = computed(() => {
    const hour = new Date().getHours();
    const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    const name = this.authService.user()?.name?.split(' ')[0];
    return `${greeting}${name ? ', ' + name : ''}`;
  });
  protected readonly orderMix = computed(() => {
    const d = this.data();
    const delivered = d?.delivered_today ?? 0;
    const cancelled = d?.cancelled_today ?? 0;
    const other = Math.max(0, (d?.orders_today ?? 0) - delivered - cancelled);
    const total = delivered + cancelled + other;
    return [
      { label: 'Delivered', value: delivered, color: '#1688f8' },
      { label: 'Other orders', value: other, color: '#90c8ff' },
      { label: 'Cancelled', value: cancelled, color: '#8d9bad' },
    ].map(item => ({ ...item, percent: total ? item.value / total * 100 : 0 }));
  });
  protected readonly activity = computed(() => {
    const today = new Date();
    const bins = Array<number>(12).fill(0);
    for (const delivery of this.data()?.recent_deliveries ?? []) {
      const date = new Date(delivery.created_at);
      if (date.toDateString() === today.toDateString()) bins[Math.floor(date.getHours() / 2)]++;
    }
    const max = Math.max(1, ...bins);
    const points = bins.map((count, index) => ({ x: 20 + index * 60, y: 170 - count / max * 130, count, label: `${String(index * 2).padStart(2, '0')}:00` }));
    return { points, line: points.map(p => `${p.x},${p.y}`).join(' '), area: `M20,180 L${points.map(p => `${p.x},${p.y}`).join(' L')} L680,180 Z`, count: bins.reduce((a, b) => a + b, 0) };
  });
  constructor() { this.dashboardService.load(); }
  protected retry(): void { this.dashboardService.load(); }
  protected formatTime(iso: string | undefined): string {
    return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
  }
}
