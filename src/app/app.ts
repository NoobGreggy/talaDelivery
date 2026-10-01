import { afterEveryRender, Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemeService } from './core/theme/theme.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  template: '<router-outlet />',
  styles: [':host { display: block; }'],
})
export class App {
  // Instantiating the service here applies the saved/system theme before any
  // routed screen renders and keeps it synchronized for the whole workspace.
  private readonly theme = inject(ThemeService);

  constructor() {
    // Re-scan routed content so Tala Icons renders after navigation and
    // asynchronous list updates.
    afterEveryRender(() => {
      const talaIcons = (window as Window & { TalaIcons?: { render(): void } }).TalaIcons;
      talaIcons?.render();
    });
  }
}
