import { Component, computed, inject, input } from '@angular/core';
import { DomSanitizer } from '@angular/platform-browser';
import type { IconName } from 'tala-icons';
import { TALA_ICON_PATHS } from './tala-icons.generated';

@Component({
  selector: 'app-tala-icon', standalone: true,
  template: `<svg xmlns="http://www.w3.org/2000/svg" [attr.width]="size()" [attr.height]="size()"
    viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"
    stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" [innerHTML]="content()"></svg>`,
  host: { 'aria-hidden': 'true' },
  styles: [':host { display: inline-flex; flex-shrink: 0; vertical-align: middle; } svg { display: block; }'],
})
export class TalaIconComponent {
  name = input.required<IconName>();
  size = input(18);
  private readonly sanitizer = inject(DomSanitizer);
  // Only installed Tala package artwork is trusted; no user-provided SVG or HTML.
  protected readonly content = computed(() => this.sanitizer.bypassSecurityTrustHtml(TALA_ICON_PATHS[this.name()] ?? ''));
}
