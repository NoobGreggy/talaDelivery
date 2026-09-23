import { Component, signal } from '@angular/core';
import { ButtonComponent } from '../../../shared/components/button/button';

@Component({
  selector: 'app-settings-page',
  standalone: true,
  imports: [ButtonComponent],
  templateUrl: './settings-page.html',
  styleUrl: './settings-page.css',
})
export class SettingsPageComponent {
  protected readonly saved = signal(false);

  protected save(): void {
    this.saved.set(true);
    setTimeout(() => this.saved.set(false), 2000);
  }
}