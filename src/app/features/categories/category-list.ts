import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { StoreCategoryService } from '../../core/services/store-category.service';
import { ToastService } from '../../core/services/toast.service';
import { StoreCategory } from '../../core/models';
import { ButtonComponent } from '../../shared/components/button/button';
import { ModalComponent } from '../../shared/components/modal/modal';
import { ErrorStateComponent } from '../../shared/components/error-state/error-state';
import { EmptyStateComponent } from '../../shared/components/empty-state/empty-state';
import { SearchInputComponent } from '../../shared/components/search-input/search-input';

@Component({
  selector: 'app-category-list', standalone: true,
  imports: [ReactiveFormsModule, ButtonComponent, ModalComponent, ErrorStateComponent, EmptyStateComponent, SearchInputComponent],
  templateUrl: './category-list.html',
  styles: [`@font-face { font-family: TalaFlutterIcons; src: url('/fonts/materialicons-regular.otf') format('opentype'); font-display: block; }
    .flutter-icon { font-family: TalaFlutterIcons; font-weight: normal; font-style: normal; font-size: 28px; line-height: 1; }`],
})
export class CategoryListComponent {
  private readonly service = inject(StoreCategoryService);
  private readonly toast = inject(ToastService);
  private readonly fb = inject(FormBuilder);
  protected readonly categories = signal<StoreCategory[]>([]);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);
  protected readonly search = signal('');
  protected readonly modalOpen = signal(false);
  protected readonly editing = signal<StoreCategory | null>(null);
  protected readonly saving = signal(false);
  protected readonly icons = signal<{ key: string; label: string }[]>([]);
  protected iconGlyph(key: string): string {
    const codepoints: Record<string, number> = {
      restaurant_rounded: 0xf0108, local_grocery_store_rounded: 0xf86e,
      medication_rounded: 0xf8b1, inventory_2_rounded: 0xf822,
      local_offer_rounded: 0xf875, grid_view_rounded: 0xf7c4,
    };
    return String.fromCodePoint(codepoints[key] ?? codepoints['restaurant_rounded']);
  }
  protected readonly formError = signal<string | null>(null);
  protected readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.maxLength(80), Validators.pattern(/\S/)]],
    description: ['', Validators.maxLength(500)], is_active: [true],
    icon: ['restaurant_rounded', Validators.required],
  });
  protected readonly filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    return this.categories().filter((category) => `${category.name} ${category.description ?? ''}`.toLowerCase().includes(term));
  });
  constructor() {
    this.load();
    this.service.icons().subscribe({
      next: (icons) => this.icons.set(icons),
      error: () => this.toast.show('Unable to load Flutter category icons. Reload this page.', 'error'),
    });
  }
  protected load(): void {
    this.loading.set(true); this.error.set(null);
    this.service.list().subscribe({
      next: (items) => { this.categories.set(items); this.loading.set(false); },
      error: () => { this.error.set('Unable to load store categories.'); this.loading.set(false); },
    });
  }
  protected open(category: StoreCategory | null = null): void {
    this.editing.set(category); this.formError.set(null);
    this.form.reset({ name: category?.name ?? '', description: category?.description ?? '', is_active: category?.is_active ?? true, icon: category?.icon ?? 'restaurant_rounded' });
    this.modalOpen.set(true);
  }
  protected close(): void { if (!this.saving()) this.modalOpen.set(false); }
  protected save(): void {
    if (this.form.invalid || this.saving()) { this.form.markAllAsTouched(); return; }
    this.saving.set(true); this.formError.set(null);
    const raw = this.form.getRawValue();
    this.service.save({ ...raw, name: raw.name.trim(), description: raw.description.trim() }, this.editing()?.id).subscribe({
      next: () => { this.saving.set(false); this.modalOpen.set(false); this.toast.show('Store category saved'); this.load(); },
      error: (error) => { this.saving.set(false); this.formError.set(error.error?.message ?? 'Unable to save category.'); },
    });
  }
}
