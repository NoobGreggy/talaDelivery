import { Component, computed, input, output } from '@angular/core';

@Component({
  selector: 'app-toast',
  standalone: true,
  templateUrl: './toast.html',
  styleUrl: './toast.css',
})
export class ToastComponent {
  message = input.required<string>();
  type = input<'success' | 'error' | 'info'>('success');
  closed = output<void>();

  protected containerClasses = computed(() => {
    switch (this.type()) {
      case 'error':
        return 'bg-red-50 border-red-200 text-red-800';
      case 'info':
        return 'bg-blue-50 border-blue-200 text-blue-800';
      default:
        return 'bg-emerald-50 border-emerald-200 text-emerald-800';
    }
  });
}