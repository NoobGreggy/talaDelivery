import { Component, input, output, signal } from '@angular/core';

@Component({
  selector: 'app-select',
  standalone: true,
  templateUrl: './select.html',
  styleUrl: './select.css',
})
export class SelectComponent {
  label = input('');
  placeholder = input('Select...');
  options = input<{ value: string; label: string }[]>([]);
  value = signal('');
  valueChange = output<string>();

  protected onSelect(event: Event): void {
    const target = event.target as HTMLSelectElement;
    this.value.set(target.value);
    this.valueChange.emit(target.value);
  }
}