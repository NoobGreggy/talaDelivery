import { Component, inject, signal, computed } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { CategoryService } from '../../../core/services/category.service';
import { ToastService } from '../../../core/services/toast.service';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { Category } from '../../../core/models';

@Component({
  selector: 'app-category-list',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    ButtonComponent,
    ModalComponent,
    ConfirmDialogComponent,
    EmptyStateComponent,
    ErrorStateComponent,
  ],
  templateUrl: './category-list.html',
  styleUrl: './category-list.css',
})
export class CategoryListComponent {
  private categoryService = inject(CategoryService);
  private toastService = inject(ToastService);
  private fb = inject(FormBuilder);

  protected readonly categories = this.categoryService.categories;
  protected readonly loading = this.categoryService.loading;
  protected readonly error = this.categoryService.error;

  protected readonly formModalOpen = signal(false);
  protected readonly editingCategory = signal<Category | null>(null);
  protected readonly deleteTarget = signal<Category | null>(null);
  protected readonly acting = signal(false);
  protected readonly formError = signal<string | null>(null);

  protected readonly form = this.fb.group({
    name: ['', Validators.required],
    description: [''],
  });

  constructor() {
    this.categoryService.load();
  }

  protected refresh(): void {
    this.categoryService.load();
  }

  protected openCreate(): void {
    this.editingCategory.set(null);
    this.formError.set(null);
    this.form.reset({ name: '', description: '' });
    this.formModalOpen.set(true);
  }

  protected openEdit(category: Category): void {
    this.editingCategory.set(category);
    this.formError.set(null);
    this.form.setValue({
      name: category.name,
      description: category.description ?? '',
    });
    this.formModalOpen.set(true);
  }

  protected closeModal(): void {
    this.formModalOpen.set(false);
    this.editingCategory.set(null);
  }

  protected save(): void {
    if (this.form.invalid) return;

    const editing = this.editingCategory();
    const raw = this.form.getRawValue();
    const payload: Partial<Category> = {
      name: raw.name ?? '',
      description: raw.description || undefined,
    };
    this.acting.set(true);
    this.formError.set(null);

    const request = editing
      ? this.categoryService.updateCategory(editing.id, payload)
      : this.categoryService.createCategory(payload);

    request.subscribe({
      next: () => {
        this.acting.set(false);
        this.closeModal();
        this.categoryService.load();
        this.toastService.show(editing ? 'Category updated' : 'Category created');
      },
      error: () => {
        this.acting.set(false);
        this.formError.set('Unable to save category. Please try again.');
        this.toastService.show('Unable to save category', 'error');
      },
    });
  }

  protected confirmDelete(): void {
    const category = this.deleteTarget();
    if (!category) return;

    this.acting.set(true);
    this.categoryService.deleteCategory(category.id).subscribe({
      next: () => {
        this.acting.set(false);
        this.deleteTarget.set(null);
        this.categoryService.load();
        this.toastService.show('Category deleted');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to delete category', 'error');
      },
    });
  }

  protected trackById(_: number, category: Category): number {
    return category.id;
  }
}