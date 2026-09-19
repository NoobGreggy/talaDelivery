import { Component, input } from '@angular/core';

@Component({
  selector: 'app-timeline',
  standalone: true,
  templateUrl: './timeline.html',
  styleUrl: './timeline.css',
})
export class TimelineComponent {
  events = input.required<{ label: string; time?: string; active?: boolean; completed?: boolean }[]>();
}