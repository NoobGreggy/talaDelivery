import { Component, computed, input } from '@angular/core';

@Component({
  selector: 'app-card',
  standalone: true,
  templateUrl: './card.html',
  styleUrl: './card.css',
})
export class CardComponent {
  padding = input(true);

  protected paddingClasses = computed(() => (this.padding() ? 'p-6' : ''));
}