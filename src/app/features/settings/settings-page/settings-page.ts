import { Component, inject, signal, computed, OnInit, effect } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { StoreProfileService } from '../../../core/services/store-profile.service';
import { ToastService } from '../../../core/services/toast.service';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { CardComponent } from '../../../shared/components/card/card';

@Component({
  selector: 'app-settings-page',
  standalone: true,
  imports: [ReactiveFormsModule, ButtonComponent, ErrorStateComponent, CardComponent],
  templateUrl: './settings-page.html',
  styleUrl: './settings-page.css',
})
export class SettingsPageComponent implements OnInit {
  private profileService = inject(StoreProfileService);
  private toastService = inject(ToastService);
  private fb = inject(FormBuilder);

  protected readonly profile = this.profileService.profile;
  protected readonly loading = this.profileService.loading;
  protected readonly error = this.profileService.error;

  protected readonly saving = signal(false);
  protected readonly saveError = signal<string | null>(null);

  protected readonly form = this.fb.group({
    name: ['', Validators.required],
    description: [''],
    phone: [''],
    email: ['', Validators.email],
    address: ['', Validators.required],
    opening_time: [''],
    closing_time: [''],
  });

  protected readonly isLoadingProfile = computed(() => {
    return this.loading() && !this.profile();
  });

  constructor() {
    effect(() => {
      this.onProfileLoaded();
    });
  }

  ngOnInit(): void {
    this.profileService.load();
  }

  protected readonly storeStatus = computed(() => this.profile()?.status ?? 'INACTIVE');
  protected readonly ordersToday = computed(() => this.profile()?.orders_today ?? 0);

  protected retry(): void {
    this.profileService.load();
  }

  protected onProfileLoaded(): void {
    const p = this.profile();
    if (!p) return;
    this.form.setValue({
      name: p.name ?? '',
      description: p.description ?? '',
      phone: p.phone ?? '',
      email: p.email ?? '',
      address: p.address ?? '',
      opening_time: p.opening_time ?? '',
      closing_time: p.closing_time ?? '',
    });
  }

  protected save(): void {
    if (this.form.invalid) return;

    const raw = this.form.getRawValue();
    this.saving.set(true);
    this.saveError.set(null);

    this.profileService
      .updateProfile({
        name: raw.name ?? '',
        description: raw.description || undefined,
        phone: raw.phone || undefined,
        email: raw.email || undefined,
        address: raw.address ?? '',
        opening_time: raw.opening_time || undefined,
        closing_time: raw.closing_time || undefined,
      })
      .subscribe({
        next: () => {
          this.saving.set(false);
          this.toastService.show('Store settings saved');
        },
        error: () => {
          this.saving.set(false);
          this.saveError.set('Unable to save settings. Please try again.');
          this.toastService.show('Unable to save settings', 'error');
        },
      });
  }
}