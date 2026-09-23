import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { PlatformSettings } from '../../../core/models';
import { PlatformSettingsService } from '../../../core/services/platform-settings.service';
import { ButtonComponent } from '../../../shared/components/button/button';

@Component({
  selector: 'app-settings-page',
  standalone: true,
  imports: [ReactiveFormsModule, ButtonComponent],
  templateUrl: './settings-page.html',
  styleUrl: './settings-page.css',
})
export class SettingsPageComponent {
  private settingsService = inject(PlatformSettingsService);
  private fb = inject(FormBuilder);

  protected readonly saved = signal(false);
  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly form = this.fb.nonNullable.group({
    rider_commission_type: ['PERCENTAGE' as 'PERCENTAGE' | 'FIXED', Validators.required],
    rider_commission_value: [0, [Validators.required, Validators.min(0)]],
    earnings_week_type: [
      'ROLLING_SEVEN_DAYS' as 'ROLLING_SEVEN_DAYS' | 'CALENDAR_WEEK',
      Validators.required,
    ],
    week_starts_on: [1, [Validators.required, Validators.min(0), Validators.max(6)]],
    settlement_timezone: ['Asia/Manila', Validators.required],
    settlement_day_starts_at: ['00:00', Validators.required],
    distance_method: ['STRAIGHT_LINE' as const, Validators.required],
  });

  constructor() {
    this.load();
  }

  protected save(): void {
    if (this.form.invalid || this.saving()) return;
    this.saving.set(true);
    this.error.set(null);
    this.settingsService.update(this.form.getRawValue() as PlatformSettings).subscribe({
      next: (settings) => {
        this.form.patchValue(settings);
        this.saving.set(false);
        this.saved.set(true);
        setTimeout(() => this.saved.set(false), 2000);
      },
      error: () => {
        this.saving.set(false);
        this.error.set('Unable to save platform settings.');
      },
    });
  }

  private load(): void {
    this.settingsService.get().subscribe({
      next: (settings) => {
        this.form.patchValue(settings);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.error.set('Unable to load platform settings.');
      },
    });
  }
}
