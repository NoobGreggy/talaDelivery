import {
  Component,
  ElementRef,
  HostListener,
  input,
  output,
  signal,
  inject,
} from '@angular/core';

@Component({
  selector: 'app-dropdown',
  standalone: true,
  templateUrl: './dropdown.html',
  styleUrl: './dropdown.css',
})
export class DropdownComponent {
  private elementRef = inject(ElementRef);

  items = input<{ label: string; icon?: string; danger?: boolean }[]>([]);
  itemClick = output<string>();
  isOpen = signal(false);

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    const target = event.target as HTMLElement;
    if (!this.elementRef.nativeElement.contains(target)) {
      this.isOpen.set(false);
    }
  }

  toggle(): void {
    this.isOpen.update((open) => !open);
  }

  selectItem(label: string): void {
    this.itemClick.emit(label);
    this.isOpen.set(false);
  }
}