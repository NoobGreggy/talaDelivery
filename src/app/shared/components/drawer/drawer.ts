import { Component, computed, input, output } from '@angular/core';

@Component({
  selector: 'app-drawer',
  standalone: true,
  templateUrl: './drawer.html',
  styleUrl: './drawer.css',
})
export class DrawerComponent {
  title = input('');
  open = input(false);
  side = input<'right' | 'left'>('right');
  closed = output<void>();

  protected positionClasses = computed(() =>
    this.side() === 'left'
      ? 'left-0 top-0 h-full w-full max-w-md border-r'
      : 'right-0 top-0 h-full w-full max-w-md border-l'
  );

  protected translateClasses = computed(() => {
    const base = 'transform transition-transform duration-300 ease-in-out';
    if (!this.open()) {
      return this.side() === 'left'
        ? base + ' -translate-x-full'
        : base + ' translate-x-full';
    }
    return base + ' translate-x-0';
  });

  protected overlayClasses = computed(() =>
    this.open()
      ? 'fixed inset-0 z-40 bg-slate-900/50 backdrop-blur-sm transition-opacity duration-300 opacity-100'
      : 'fixed inset-0 z-40 bg-slate-900/50 backdrop-blur-sm transition-opacity duration-300 opacity-0 pointer-events-none'
  );

  close(): void {
    this.closed.emit();
  }
}