import { Component, computed, input, output } from '@angular/core';

@Component({
  selector: 'app-icon-button',
  standalone: true,
  templateUrl: './icon-button.html',
  styleUrl: './icon-button.css',
})
export class IconButtonComponent {
  ariaLabel = input.required<string>();
  disabled = input(false);
  variant = input<'ghost' | 'secondary'>('ghost');
  size = input<'sm' | 'md'>('md');
  clicked = output<void>();

  protected variantClasses = computed(() =>
    this.variant() === 'secondary'
      ? 'bg-white text-slate-700 border border-slate-300 hover:bg-slate-50'
      : 'bg-transparent text-slate-500 hover:bg-slate-100 hover:text-slate-700'
  );

  protected sizeClasses = computed(() =>
    this.size() === 'sm' ? 'h-8 w-8' : 'h-10 w-10'
  );

  protected handleClick(): void {
    if (!this.disabled()) {
      this.clicked.emit();
    }
  }
}