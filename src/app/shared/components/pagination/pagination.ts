import { Component, computed, input, output } from '@angular/core';

@Component({
  selector: 'app-pagination',
  standalone: true,
  templateUrl: './pagination.html',
  styleUrl: './pagination.css',
})
export class PaginationComponent {
  currentPage = input(1);
  totalPages = input(1);
  pageChange = output<number>();

  protected pages = computed(() => {
    const total = Math.max(1, this.totalPages());
    return Array.from({ length: total }, (_, index) => index + 1);
  });

  protected goToPage(page: number): void {
    const clamped = Math.min(Math.max(1, page), this.totalPages());
    if (clamped !== this.currentPage()) {
      this.pageChange.emit(clamped);
    }
  }
}