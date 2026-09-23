import { Component, input } from '@angular/core';

@Component({
  selector: 'app-skeleton',
  standalone: true,
  templateUrl: './skeleton.html',
  styleUrl: './skeleton.css',
})
export class SkeletonComponent {
  width = input('100%');
  height = input('20px');
  borderRadius = input('4px');
}

@Component({
  selector: 'app-table-skeleton',
  standalone: true,
  templateUrl: './table-skeleton.html',
  styleUrl: './skeleton.css',
})
export class TableSkeletonComponent {
  rows = input(5);
  columns = input(4);
}

@Component({
  selector: 'app-card-skeleton',
  standalone: true,
  templateUrl: './card-skeleton.html',
  styleUrl: './skeleton.css',
})
export class CardSkeletonComponent {
  lines = input(3);
}