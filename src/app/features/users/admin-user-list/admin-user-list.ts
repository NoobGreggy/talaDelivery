import { DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { AdminUser, AdminUserStatus } from '../../../core/models';
import { AdminUserService } from '../../../core/services/admin-user.service';
import { AuthService } from '../../../core/auth/auth.service';
import { ToastService } from '../../../core/services/toast.service';
import { AvatarComponent } from '../../../shared/components/avatar/avatar';
import { ButtonComponent } from '../../../shared/components/button/button';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog';
import { DropdownComponent } from '../../../shared/components/dropdown/dropdown';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state';
import { ErrorStateComponent } from '../../../shared/components/error-state/error-state';
import { ModalComponent } from '../../../shared/components/modal/modal';
import { SearchInputComponent } from '../../../shared/components/search-input/search-input';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge';

/**
 * Platform-admin account management: create, reset password, enable/disable.
 *
 * There is no delete. Revoking access is done by moving the account out of
 * ACTIVE, which preserves the audit trail that destroying the row would erase.
 */
@Component({
  selector: 'app-admin-user-list',
  standalone: true,
  imports: [
    DatePipe,
    ReactiveFormsModule,
    AvatarComponent,
    ButtonComponent,
    ConfirmDialogComponent,
    DropdownComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    ModalComponent,
    SearchInputComponent,
    StatusBadgeComponent,
  ],
  templateUrl: './admin-user-list.html',
  styleUrl: './admin-user-list.css',
})
export class AdminUserListComponent {
  private adminUserService = inject(AdminUserService);
  private toastService = inject(ToastService);
  private authService = inject(AuthService);
  private fb = inject(FormBuilder);

  protected readonly users = this.adminUserService.users;
  protected readonly loading = this.adminUserService.loading;
  protected readonly error = this.adminUserService.error;

  protected readonly searchTerm = signal('');
  protected readonly statusFilter = signal('all');
  protected readonly modalOpen = signal(false);
  protected readonly acting = signal(false);
  protected readonly formError = signal<string | null>(null);

  protected readonly passwordModalOpen = signal(false);
  protected readonly passwordTarget = signal<AdminUser | null>(null);
  protected readonly passwordError = signal<string | null>(null);

  protected readonly statusTarget = signal<AdminUser | null>(null);
  protected readonly detailTarget = signal<AdminUser | null>(null);

  /** The signed-in admin, so their own row can hide destructive actions. */
  protected readonly currentUserId = this.authService.user()?.id ?? null;

  protected readonly activeCount = computed(
    () => this.users().filter((user) => user.status === 'ACTIVE').length,
  );

  protected readonly filteredUsers = computed(() => {
    const term = this.searchTerm().trim().toLowerCase();
    const status = this.statusFilter();

    return this.users().filter((user) => {
      const matchesStatus = status === 'all' || user.status === status;
      const haystack = `${user.name} ${user.email} ${user.phone ?? ''}`.toLowerCase();
      return matchesStatus && (!term || haystack.includes(term));
    });
  });

  protected readonly form = this.fb.group({
    name: ['', [Validators.required, Validators.maxLength(255)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(255)]],
    phone: ['', Validators.maxLength(20)],
    // Mirrors the API's `@MinLength(8)`, so an obviously-too-short password is
    // caught before a round trip rather than as a 422.
    password: ['', [Validators.required, Validators.minLength(8)]],
    status: ['ACTIVE' as AdminUserStatus, Validators.required],
  });

  protected readonly passwordForm = this.fb.group({
    password: ['', [Validators.required, Validators.minLength(8)]],
    confirmPassword: ['', Validators.required],
  });

  constructor() {
    this.adminUserService.load();
  }

  protected onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  protected setStatusFilter(status: string): void {
    this.statusFilter.set(status);
  }

  protected refresh(): void {
    this.adminUserService.refresh();
  }

  protected openCreate(): void {
    this.formError.set(null);
    this.form.reset({
      name: '',
      email: '',
      phone: '',
      password: '',
      status: 'ACTIVE',
    });
    this.modalOpen.set(true);
  }

  protected closeModal(): void {
    this.modalOpen.set(false);
    this.formError.set(null);
  }

  protected save(): void {
    if (this.form.invalid || this.acting()) {
      this.form.markAllAsTouched();
      return;
    }

    this.acting.set(true);
    this.formError.set(null);
    const raw = this.form.getRawValue();

    this.adminUserService
      .createUser({
        name: raw.name?.trim() ?? '',
        email: raw.email?.trim() ?? '',
        phone: raw.phone?.trim() || null,
        password: raw.password ?? '',
        status: raw.status ?? 'ACTIVE',
      })
      .subscribe({
        next: () => {
          this.acting.set(false);
          this.closeModal();
          this.adminUserService.load();
          this.toastService.show('Admin user created');
        },
        error: (error: HttpErrorResponse) => {
          this.acting.set(false);
          this.formError.set(this.apiError(error, 'Unable to create the admin user.'));
        },
      });
  }

  protected openPasswordReset(user: AdminUser): void {
    this.passwordTarget.set(user);
    this.passwordError.set(null);
    this.passwordForm.reset({ password: '', confirmPassword: '' });
    this.passwordModalOpen.set(true);
  }

  protected closePasswordReset(): void {
    this.passwordModalOpen.set(false);
    this.passwordTarget.set(null);
    this.passwordError.set(null);
  }

  protected savePassword(): void {
    const target = this.passwordTarget();
    const raw = this.passwordForm.getRawValue();
    if (!target || this.acting()) return;

    // Checked client-side too, so a typo surfaces inline instead of as a 422.
    if (raw.password !== raw.confirmPassword) {
      this.passwordError.set('The two passwords do not match.');
      return;
    }
    if (this.passwordForm.invalid) {
      this.passwordForm.markAllAsTouched();
      return;
    }

    this.acting.set(true);
    this.passwordError.set(null);

    this.adminUserService.changePassword(target.id, raw.password ?? '').subscribe({
      next: () => {
        this.acting.set(false);
        this.closePasswordReset();
        this.toastService.show(`Password reset for ${target.name}`);
      },
      error: (error: HttpErrorResponse) => {
        this.acting.set(false);
        this.passwordError.set(this.apiError(error, 'Unable to update the password.'));
      },
    });
  }

  protected openStatusChange(user: AdminUser, next: AdminUserStatus): void {
    this.statusTarget.set(user);
    this.statusChoice.set(next);
  }

  protected closeStatusChange(): void {
    this.statusTarget.set(null);
    this.statusChoice.set('ACTIVE');
  }

  /**
   * The status the confirm dialog will apply. Held separately from the target
   * because the backend supports three states, so "Disable" and "Suspend" both
   * have to name the value they will write rather than infer it.
   */
  protected readonly statusChoice = signal<AdminUserStatus>('ACTIVE');

  protected readonly statusChoiceLabel = computed(() => {
    switch (this.statusChoice()) {
      case 'INACTIVE':
        return 'Disable';
      case 'SUSPENDED':
        return 'Suspend';
      default:
        return 'Enable';
    }
  });

  protected confirmStatusChange(): void {
    const target = this.statusTarget();
    if (!target || this.acting()) return;

    const next = this.statusChoice();
    this.acting.set(true);

    this.adminUserService.updateStatus(target.id, next).subscribe({
      next: () => {
        this.acting.set(false);
        this.closeStatusChange();
        this.adminUserService.load();
        this.toastService.show(
          next === 'ACTIVE' ? `${target.name} enabled` : `${target.name} ${next.toLowerCase()}`,
        );
      },
      error: (error: HttpErrorResponse) => {
        this.acting.set(false);
        this.closeStatusChange();
        this.toastService.show(this.apiError(error, 'Unable to update the account'), 'error');
      },
    });
  }

  protected isSelf(user: AdminUser): boolean {
    return user.id === this.currentUserId;
  }

  /**
   * Menu contents per row. The signed-in admin's own row omits the status
   * actions, because the API refuses self-demotion with a 403 and offering a
   * button that always fails is worse than not offering it.
   */
  protected userMenu(user: AdminUser): { label: string; icon?: string; danger?: boolean }[] {
    const items: { label: string; icon?: string; danger?: boolean }[] = [
      { label: 'View details' },
      { label: 'Reset password' },
    ];

    if (this.isSelf(user)) return items;

    if (user.status === 'ACTIVE') {
      items.push({ label: 'Disable', danger: true });
      items.push({ label: 'Suspend', danger: true });
    } else {
      items.push({ label: 'Enable' });
    }
    return items;
  }

  protected openDetail(user: AdminUser): void {
    this.detailTarget.set(user);
  }

  protected closeDetail(): void {
    this.detailTarget.set(null);
  }

  protected onRowAction(action: string, user: AdminUser): void {
    switch (action) {
      case 'View details':
        this.openDetail(user);
        break;
      case 'Reset password':
        this.openPasswordReset(user);
        break;
      case 'Disable':
        this.openStatusChange(user, 'INACTIVE');
        break;
      case 'Suspend':
        this.openStatusChange(user, 'SUSPENDED');
        break;
      case 'Enable':
        this.openStatusChange(user, 'ACTIVE');
        break;
    }
  }

  protected fieldInvalid(name: string): boolean {
    const control = this.form.get(name);
    return !!control && control.invalid && control.touched;
  }

  protected passwordFieldInvalid(name: string): boolean {
    const control = this.passwordForm.get(name);
    return !!control && control.invalid && control.touched;
  }

  protected trackById(_: number, user: AdminUser): number {
    return user.id;
  }

  /** Surfaces the API's Laravel-shaped `{ field: [messages] }` 422 first. */
  private apiError(error: HttpErrorResponse, fallback: string): string {
    const errors = error.error?.errors as Record<string, string[]> | undefined;
    const first = errors ? Object.values(errors).flat()[0] : undefined;
    return first ?? error.error?.message ?? fallback;
  }
}