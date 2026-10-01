import { Component, computed, input, output } from '@angular/core';

@Component({
  selector: 'app-icon-button',
  standalone: true,
  templateUrl: './icon-button.html',
  styleUrl: './icon-button.css',
})
export class IconButtonComponent {
  ariaLabel = input.required<string>();
  title = input<string>('');
  disabled = input(false);
  variant = input<'ghost' | 'secondary' | 'danger'>('ghost');
  size = input<'sm' | 'md'>('md');
  clicked = output<void>();

  protected variantClasses = computed(() => {
    switch (this.variant()) {
      case 'secondary':
        return 'bg-[var(--app-surface)] text-[var(--app-muted)] border border-[var(--app-border)] hover:bg-[var(--app-hover)] hover:text-[var(--app-ink)]';
      case 'danger':
        return 'bg-transparent text-red-500 hover:bg-red-500/10 hover:text-red-700';
      default:
        return 'bg-transparent text-[var(--app-muted)] hover:bg-[var(--app-hover)] hover:text-[var(--app-ink)]';
    }
  });

  protected sizeClasses = computed(() => (this.size() === 'sm' ? 'h-8 w-8' : 'h-10 w-10'));

  protected handleClick(): void {
    if (!this.disabled()) {
      this.clicked.emit();
    }
  }
}
