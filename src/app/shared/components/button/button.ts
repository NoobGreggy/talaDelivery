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
        return 'bg-white text-slate-700 border border-slate-300 hover:bg-slate-50';
      case 'ghost':
        return 'bg-transparent text-slate-600 hover:bg-slate-100';
      case 'danger':
        return 'bg-red-600 text-white hover:bg-red-700';
      default:
        return 'bg-sky-600 text-white hover:bg-sky-700';
    }
  });

  protected sizeClasses = computed(() => {
    switch (this.size()) {
      case 'sm':
        return 'px-2.5 py-1.5 text-xs';
      case 'lg':
        return 'px-6 py-3 text-base';
      default:
        return 'px-4 py-2 text-sm';
    }
  });

  protected baseClasses =
    'inline-flex items-center justify-center gap-2 font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-sky-500 disabled:opacity-50 disabled:cursor-not-allowed';

  protected handleClick(): void {
    if (!this.disabled() && !this.loading()) {
      this.clicked.emit();
    }
  }
}