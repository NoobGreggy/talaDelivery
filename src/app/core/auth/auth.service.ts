import { Injectable, signal, computed, inject } from '@angular/core';
import { Router } from '@angular/router';
import { ApiClientService } from '../api/api-client.service';
import { User, LoginRequest, LoginResponse } from '../models';
import { Observable, tap, catchError, of } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private api = inject(ApiClientService);
  private router = inject(Router);

  private currentUser = signal<User | null>(this.readStoredUser());
  private token = signal<string | null>(localStorage.getItem('auth_token'));
  private initialized = signal(false);

  user = this.currentUser.asReadonly();
  isAuthenticated = computed(() => !!this.token());
  isInitialized = this.initialized.asReadonly();
  isPlatformAdmin = computed(() => this.currentUser()?.role === 'platform_admin');
  isStoreAdmin = computed(() => this.currentUser()?.role === 'store_admin');

  login(credentials: LoginRequest): Observable<LoginResponse> {
    return this.api.post<LoginResponse>('/auth/login', credentials).pipe(
      tap(response => {
        this.token.set(response.token);
        this.currentUser.set(response.user);
        localStorage.setItem('auth_token', response.token);
        localStorage.setItem('auth_user', JSON.stringify(response.user));
      })
    );
  }

  logout(): void {
    this.token.set(null);
    this.currentUser.set(null);
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
    this.router.navigate(['/login']);
  }

  getToken(): string | null {
    return this.token();
  }

  getStoreId(): number | null {
    const user = this.currentUser();
    const storeId = user?.store_id ?? user?.stores?.[0]?.id;
    return storeId && storeId > 0 ? storeId : null;
  }

  hasRole(role: string): boolean {
    return this.currentUser()?.role === role;
  }

  loadUser(): Observable<User | null> {
    if (!this.token()) {
      this.initialized.set(true);
      return of(null);
    }
    return this.api.get<User>('/auth/me').pipe(
      tap(user => {
        this.currentUser.set(user);
        localStorage.setItem('auth_user', JSON.stringify(user));
        this.initialized.set(true);
      }),
      catchError(() => {
        this.logout();
        this.initialized.set(true);
        return of(null);
      })
    );
  }

  private readStoredUser(): User | null {
    const stored = localStorage.getItem('auth_user');
    if (!stored) return null;
    try {
      return JSON.parse(stored) as User;
    } catch {
      return null;
    }
  }
}