import { Component, computed, input } from '@angular/core';

@Component({
  selector: 'app-avatar',
  standalone: true,
  templateUrl: './avatar.html',
  styleUrl: './avatar.css',
})
export class AvatarComponent {
  name = input.required<string>();
  size = input<'sm' | 'md' | 'lg'>('md');
  src = input('');

  protected initials = computed(() => {
    const parts = this.name()
      .split(' ')
      .filter(Boolean);
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return this.name().substring(0, 2).toUpperCase();
  });

  protected sizeClasses = computed(() => {
    switch (this.size()) {
      case 'sm':
        return 'h-8 w-8 text-xs';
      case 'lg':
        return 'h-14 w-14 text-lg';
      default:
        return 'h-10 w-10 text-sm';
    }
  });

  protected bgColor = computed(() => {
    let hash = 0;
    for (const char of this.name()) {
      hash = char.charCodeAt(0) + ((hash << 5) - hash);
    }
    const colors = [
      'bg-indigo-100 text-indigo-700',
      'bg-emerald-100 text-emerald-700',
      'bg-sky-100 text-sky-700',
      'bg-amber-100 text-amber-700',
      'bg-rose-100 text-rose-700',
      'bg-violet-100 text-violet-700',
      'bg-cyan-100 text-cyan-700',
      'bg-fuchsia-100 text-fuchsia-700',
    ];
    return colors[Math.abs(hash) % colors.length];
  });
}