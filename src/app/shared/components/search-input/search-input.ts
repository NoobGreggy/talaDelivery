import { TalaIconComponent } from '../tala-icon/tala-icon';
import { Component, input, output, signal } from '@angular/core';

@Component({
  selector: 'app-search-input',
  standalone: true,
  imports: [TalaIconComponent],
  templateUrl: './search-input.html',
  styleUrl: './search-input.css',
})
export class SearchInputComponent {
  placeholder = input('Search...');
  value = signal('');
  valueChange = output<string>();

  protected onInput(event: Event): void {
    const target = event.target as HTMLInputElement;
    this.value.set(target.value);
    this.valueChange.emit(target.value);
  }
}