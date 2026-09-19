import { Component, inject, signal, computed } from '@angular/core';
import { CurrencyPipe } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ProductService } from '../../../core/services/product.service';
import { CategoryService } from '../../../core/services/category.service';
import { ToastService } from '../../../core/services/toast.service';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { Product } from '../../../core/models';

@Component({
  selector: 'app-product-list',
  standalone: true,
  imports: [
    CurrencyPipe,
    ReactiveFormsModule,
    ButtonComponent,
    ModalComponent,
    ConfirmDialogComponent,
    SearchInputComponent,
    EmptyStateComponent,
    ErrorStateComponent,
  ],
  templateUrl: './product-list.html',
  styleUrl: './product-list.css',
})
export class ProductListComponent {
  private productService = inject(ProductService);
  private categoryService = inject(CategoryService);
  private toastService = inject(ToastService);
  private fb = inject(FormBuilder);

  protected readonly products = this.productService.products;
  protected readonly loading = this.productService.loading;
  protected readonly error = this.productService.error;
  protected readonly categories = this.categoryService.categories;

  protected readonly searchTerm = signal('');
  protected readonly categoryFilter = signal('all');
  protected readonly formModalOpen = signal(false);
  protected readonly editingProduct = signal<Product | null>(null);
  protected readonly deleteTarget = signal<Product | null>(null);
  protected readonly acting = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly imagePreview = signal<string | null>(null);
  protected readonly imageError = signal<string | null>(null);
  protected readonly MAX_IMAGE_MB = 5;

  protected readonly filteredProducts = computed(() => {
    const term = this.searchTerm().toLowerCase();
    const cat = this.categoryFilter();
    let list = this.products();

    if (cat !== 'all') {
      list = list.filter((p) => String(p.category_id) === cat);
    }

    if (term) {
      list = list.filter(
        (p) => p.name.toLowerCase().includes(term) || (p.sku ?? '').toLowerCase().includes(term),
      );
    }

    return list;
  });

  protected readonly form = this.fb.group({
    name: ['', Validators.required],
    description: [''],
    sku: [''],
    price: [0, [Validators.required, Validators.min(0)]],
    stock: [0, [Validators.min(0)]],
    category_id: [''],
    is_available: [true],
  });

  constructor() {
    this.categoryService.load();
    this.productService.load();
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected setCategoryFilter(id: string): void {
    this.categoryFilter.set(id);
  }

  protected refresh(): void {
    this.productService.load();
  }

  protected openCreate(): void {
    this.editingProduct.set(null);
    this.formError.set(null);
    this.form.reset({
      name: '',
      description: '',
      sku: '',
      price: 0,
      stock: 0,
      category_id: '',
      is_available: true,
    });
    this.imagePreview.set(null);
    this.imageError.set(null);
    this.formModalOpen.set(true);
  }

  protected openEdit(product: Product): void {
    this.editingProduct.set(product);
    this.formError.set(null);
    this.form.setValue({
      name: product.name,
      description: product.description ?? '',
      sku: product.sku ?? '',
      price: product.price,
      stock: product.stock ?? 0,
      category_id: product.category_id ? String(product.category_id) : '',
      is_available: product.is_available,
    });
    this.imagePreview.set(product.image ?? null);
    this.imageError.set(null);
    this.formModalOpen.set(true);
  }

  protected closeModal(): void {
    this.formModalOpen.set(false);
    this.editingProduct.set(null);
    this.imagePreview.set(null);
    this.imageError.set(null);
  }

  protected onImageSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    this.imageError.set(null);

    if (!file.type.startsWith('image/')) {
      this.imageError.set('Only image files are allowed.');
      input.value = '';
      return;
    }

    if (file.size > this.MAX_IMAGE_MB * 1024 * 1024) {
      this.imageError.set(`Image must be ${this.MAX_IMAGE_MB} MB or smaller.`);
      input.value = '';
      this.imagePreview.set(null);
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      this.imagePreview.set(String(reader.result));
    };
    reader.onerror = () => {
      this.imageError.set('Unable to read the image file.');
    };
    reader.readAsDataURL(file);
  }

  protected removeImage(): void {
    this.imagePreview.set(null);
    this.imageError.set(null);
  }

  protected save(): void {
    if (this.form.invalid) return;

    const editing = this.editingProduct();
    const raw = this.form.getRawValue();
    const payload: Partial<Product> = {
      name: raw.name ?? '',
      description: raw.description || undefined,
      sku: raw.sku || undefined,
      price: raw.price ?? 0,
      stock: raw.stock ?? 0,
      category_id: raw.category_id ? Number(raw.category_id) : null,
      is_available: raw.is_available === true,
      image: this.imagePreview() ?? undefined,
    };
    this.acting.set(true);
    this.formError.set(null);

    const request = editing
      ? this.productService.updateProduct(editing.id, payload)
      : this.productService.createProduct(payload);

    request.subscribe({
      next: () => {
        this.acting.set(false);
        this.closeModal();
        this.productService.load();
        this.toastService.show(editing ? 'Product updated' : 'Product created');
      },
      error: () => {
        this.acting.set(false);
        this.formError.set('Unable to save product. Please check the details and try again.');
        this.toastService.show('Unable to save product', 'error');
      },
    });
  }

  protected toggleAvailability(product: Product): void {
    this.productService
      .updateProduct(product.id, { is_available: !product.is_available })
      .subscribe({
        next: () => {
          this.productService.load();
          this.toastService.show(product.is_available ? 'Product hidden' : 'Product listed');
        },
        error: () => this.toastService.show('Unable to update product', 'error'),
      });
  }

  protected confirmDelete(): void {
    const product = this.deleteTarget();
    if (!product) return;

    this.acting.set(true);
    this.productService.deleteProduct(product.id).subscribe({
      next: () => {
        this.acting.set(false);
        this.deleteTarget.set(null);
        this.productService.load();
        this.toastService.show('Product deleted');
      },
      error: () => {
        this.acting.set(false);
        this.toastService.show('Unable to delete product', 'error');
      },
    });
  }

  protected trackById(_: number, product: Product): number {
    return product.id;
  }

  protected toIdString(value: number): string {
    return String(value);
  }
}