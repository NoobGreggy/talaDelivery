import { DOCUMENT } from '@angular/common';
import { DestroyRef, Injectable, computed, effect, inject, signal } from '@angular/core';

export type MerchantThemePreference = 'light' | 'dark' | 'system';
export type MerchantResolvedTheme = 'light' | 'dark';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  static readonly storageKey = 'tala_merchant_theme';

  private readonly document = inject(DOCUMENT);
  private readonly destroyRef = inject(DestroyRef);
  private readonly systemQuery = window.matchMedia('(prefers-color-scheme: dark)');
  private readonly systemDark = signal(this.systemQuery.matches);

  readonly preference = signal<MerchantThemePreference>(this.readPreference());
  readonly resolved = computed<MerchantResolvedTheme>(() => {
    const preference = this.preference();
    return preference === 'system' ? (this.systemDark() ? 'dark' : 'light') : preference;
  });

  constructor() {
    const onSystemThemeChanged = (event: MediaQueryListEvent): void => {
      this.systemDark.set(event.matches);
    };
    this.systemQuery.addEventListener('change', onSystemThemeChanged);
    this.destroyRef.onDestroy(() => {
      this.systemQuery.removeEventListener('change', onSystemThemeChanged);
    });

    effect(() => {
      const preference = this.preference();
      const resolved = this.resolved();
      localStorage.setItem(ThemeService.storageKey, preference);
      this.document.documentElement.dataset['theme'] = resolved;
      this.document.documentElement.style.colorScheme = resolved;
    });
  }

  setPreference(preference: MerchantThemePreference): void {
    this.preference.set(preference);
  }

  private readPreference(): MerchantThemePreference {
    const stored = localStorage.getItem(ThemeService.storageKey);
    return stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system';
  }
}
