import {
  AfterViewInit,
  Component,
  DestroyRef,
  ElementRef,
  ViewChild,
  computed,
  inject,
  signal,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { AuthService } from '../../../core/auth/auth.service';

interface Star {
  x: number;
  y: number;
  radius: number;
  brightness: number;
  phase: number;
  speed: number;
}

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [ReactiveFormsModule],
  templateUrl: './login.html',
  styleUrl: './login.css',
})
export class LoginComponent implements AfterViewInit {
  @ViewChild('starfield') private starfield?: ElementRef<HTMLCanvasElement>;

  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private destroyRef = inject(DestroyRef);

  private stars: Star[] = [];
  private animationFrame?: number;
  private resizeObserver?: ResizeObserver;
  private reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

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

  ngAfterViewInit(): void {
    const canvas = this.starfield?.nativeElement;
    if (!canvas) return;

    const restart = (): void => {
      if (this.animationFrame !== undefined) {
        cancelAnimationFrame(this.animationFrame);
        this.animationFrame = undefined;
      }
      this.seedStars(canvas);
      this.drawStars(canvas, 0);
    };

    this.resizeObserver = new ResizeObserver(restart);
    this.resizeObserver.observe(canvas);
    this.reducedMotion.addEventListener('change', restart);
    restart();

    this.destroyRef.onDestroy(() => {
      this.resizeObserver?.disconnect();
      this.reducedMotion.removeEventListener('change', restart);
      if (this.animationFrame !== undefined) {
        cancelAnimationFrame(this.animationFrame);
      }
    });
  }

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

  private seedStars(canvas: HTMLCanvasElement): void {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.round(rect.width * dpr));
    canvas.height = Math.max(1, Math.round(rect.height * dpr));

    const count = Math.max(160, Math.min(420, Math.round((rect.width * rect.height) / 2600)));
    this.stars = Array.from({ length: count }, () => {
      const roll = Math.random();
      const bright = roll < 0.015;
      const medium = !bright && roll < 0.1;
      return {
        x: Math.random() * rect.width,
        y: Math.random() * rect.height,
        radius: bright
          ? 2.2 + Math.random() * 0.8
          : medium
            ? 1.4 + Math.random() * 0.6
            : 0.5 + Math.random() * 0.9,
        brightness: bright
          ? 0.9 + Math.random() * 0.1
          : medium
            ? 0.65 + Math.random() * 0.2
            : 0.25 + Math.random() * 0.35,
        phase: Math.random() * Math.PI * 2,
        speed: 0.4 + Math.random() * 0.8,
      };
    });
  }

  private drawStars(canvas: HTMLCanvasElement, time: number): void {
    const context = canvas.getContext('2d');
    if (!context) return;
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    context.setTransform(dpr, 0, 0, dpr, 0, 0);
    context.clearRect(0, 0, rect.width, rect.height);

    const reduced = this.reducedMotion.matches;
    for (const star of this.stars) {
      const wave = reduced ? 0 : Math.sin((time / 1000) * star.speed + star.phase) * 0.18;
      const opacity = Math.max(0.12, Math.min(1, star.brightness + wave));
      context.beginPath();
      context.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
      context.fillStyle = `rgba(255, 255, 255, ${opacity})`;
      context.fill();
    }

    if (!reduced) {
      this.animationFrame = requestAnimationFrame((nextTime) => this.drawStars(canvas, nextTime));
    }
  }
}
