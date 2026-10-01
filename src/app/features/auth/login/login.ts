import { Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [ReactiveFormsModule],
  templateUrl: './login.html',
  styleUrl: './login.css',
})
export class LoginComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);

  protected readonly loading = signal(false);
  protected readonly errorMessage = signal('');
  protected readonly passwordVisible = signal(false);
  protected readonly currentYear = new Date().getFullYear();
  protected readonly workspaceName = computed(
    () => this.authService.user()?.stores?.[0]?.name ?? 'Merchant workspace',
  );

  protected readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
  });

  protected togglePassword(): void {
    this.passwordVisible.update((visible) => !visible);
  }

  protected onSubmit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.loading.set(true);
    this.errorMessage.set('');

    this.authService.login(this.form.getRawValue()).subscribe({
      next: () => {
        this.loading.set(false);
        window.location.assign('/dashboard');
      },
      error: (error) => {
        this.loading.set(false);
        const msg =
          error?.error?.message ||
          error?.message ||
          'Unable to sign in. Please check your credentials.';
        this.errorMessage.set(msg);
      },
    });
  }
}
