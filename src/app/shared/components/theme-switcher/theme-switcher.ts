import { Component, inject, input } from '@angular/core';
import { MerchantThemePreference, ThemeService } from '../../../core/theme/theme.service';

@Component({
  selector: 'app-theme-switcher',
  standalone: true,
  templateUrl: './theme-switcher.html',
  styleUrl: './theme-switcher.css',
})
export class ThemeSwitcherComponent {
  readonly labeled = input(false);
  protected readonly theme = inject(ThemeService);

  protected setTheme(preference: MerchantThemePreference): void {
    this.theme.setPreference(preference);
  }
}
