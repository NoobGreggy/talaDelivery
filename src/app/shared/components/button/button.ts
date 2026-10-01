import { Component, computed, input, output } from '@angular/core';

@Component({
  selector: 'app-button',
  standalone: true,
  templateUrl: './button.html',
  styleUrl: './button.css',
})
export class ButtonComponent {
  type = input<'button' | 'submit' | 'reset'>('button');
  variant = input<'primary' | 'secondary' | 'ghost' | 'danger'>('primary');
  size = input<'sm' | 'md' | 'lg'>('md');
  disabled = input(false);
  loading = input(false);
  clicked = output<void>();

  protected variantClasses = computed(() => {
    switch (this.variant()) {
      case 'secondary':
        return 'bg-[var(--app-surface)] text-[var(--app-ink)] border border-[var(--app-border)] hover:bg-[var(--app-hover)]';
      case 'ghost':
        return 'bg-transparent text-[var(--app-muted)] hover:bg-[var(--app-hover)] hover:text-[var(--app-ink)]';
      case 'danger':
        return 'bg-red-600 text-white hover:bg-red-700';
      default:
        return 'bg-[var(--app-ink)] text-[var(--app-surface)] hover:opacity-90';
    }
  });

  protected sizeClasses = computed(() => {
    switch (this.size()) {
      case 'sm':
        return 'min-h-9 px-3 py-1.5 text-xs';
      case 'lg':
        return 'min-h-12 px-6 py-3 text-base';
      default:
        return 'min-h-10 px-4 py-2 text-sm';
    }
  });

  protected baseClasses =
    'inline-flex items-center justify-center gap-2 whitespace-nowrap font-bold rounded-[11px] transition-all focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-sky-500 disabled:opacity-50 disabled:cursor-not-allowed';

  protected handleClick(): void {
    if (!this.disabled() && !this.loading()) {
      this.clicked.emit();
    }
  }
}
