import { Component, computed, input, output, signal } from '@angular/core';
import { PaginationComponent } from '../pagination/pagination';

export interface DataTableColumn {
  key: string;
  label: string;
  sortable?: boolean;
  align?: 'left' | 'right' | 'center';
}

@Component({
  selector: 'app-data-table',
  standalone: true,
  imports: [PaginationComponent],
  templateUrl: './data-table.html',
  styleUrl: './data-table.css',
})
export class DataTableComponent<T> {
  columns = input.required<DataTableColumn[]>();
  data = input.required<T[]>();
  loading = input(false);
  emptyMessage = input('No data available');
  emptyDescription = input('');
  error = input('');
  searchable = input(false);
  searchPlaceholder = input('Search...');
  currentPage = input(1);
  totalPages = input(1);
  sortable = input(true);

  searchChange = output<string>();
  pageChange = output<number>();
  sortChange = output<{ key: string; direction: 'asc' | 'desc' }>();
  rowClick = output<T>();
  retried = output<void>();

  protected searchTerm = signal('');
  protected sortKey = signal('');
  protected sortDirection = signal<'asc' | 'desc'>('asc');

  protected sortedData = computed(() => {
    const rows = this.data();
    const key = this.sortKey();
    if (!key) return rows;

    const direction = this.sortDirection() === 'asc' ? 1 : -1;
    return [...rows].sort((a, b) => {
      const aVal = this.getRowValue(a, key);
      const bVal = this.getRowValue(b, key);
      if (aVal == null || bVal == null) return 0;
      if (typeof aVal === 'number' && typeof bVal === 'number') {
        return (aVal - bVal) * direction;
      }
      return String(aVal).localeCompare(String(bVal)) * direction;
    });
  });

  protected getRowValue(row: T, key: string): unknown {
    return (row as Record<string, unknown>)[key];
  }

  protected formatValue(value: unknown): string {
    if (value == null) {
      return '-';
    }
    if (value instanceof Date) {
      return value.toLocaleDateString();
    }
    return String(value);
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
    this.searchChange.emit(term);
  }

  protected toggleSort(column: DataTableColumn): void {
    if (!column.sortable || !this.sortable()) return;

    if (this.sortKey() === column.key) {
      this.sortDirection.update((direction) => (direction === 'asc' ? 'desc' : 'asc'));
    } else {
      this.sortKey.set(column.key);
      this.sortDirection.set('asc');
    }

    this.sortChange.emit({ key: column.key, direction: this.sortDirection() });
  }

  protected sortIcon(column: DataTableColumn): boolean {
    return column.sortable === true;
  }

  protected clickRow(row: T): void {
    this.rowClick.emit(row);
  }
}