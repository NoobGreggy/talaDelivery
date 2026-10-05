import { Injectable, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../api/api-client.service';
import {
  AdminUser,
  AdminUserStatus,
  CreateAdminUserRequest,
  PaginatedResponse,
} from '../models';

export interface AdminUserFilters {
  status?: string;
  search?: string;
}

/**
 * Platform-admin account management (`/admin/users`). Identity owns the users
 * table, so this is the only place an admin account can be created from the UI.
 *
 * The list is loaded with a high `per_page` and filtered client-side, matching
 * how `CustomerService` and `ZoneService` behave: those features already treat
 * the whole page as one list and filter in a `computed`, so the admin list
 * follows the same convention rather than introducing server-side paging only
 * here.
 */
@Injectable({ providedIn: 'root' })
export class AdminUserService {
  private api = inject(ApiClientService);

  private _users = signal<AdminUser[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  users = this._users.asReadonly();
  loading = this._loading.asReadonly();
  error = this._error.asReadonly();

  load(filters: AdminUserFilters = {}): void {
    this._loading.set(true);
    this._error.set(null);

    this.getUsers(filters).subscribe({
      next: (result) => {
        this._users.set(result.data);
        this._loading.set(false);
      },
      error: () => {
        this._error.set("We couldn't load admin users.");
        this._loading.set(false);
      },
    });
  }

  refresh(): void {
    this.load();
  }

  getUser(id: number): Observable<AdminUser> {
    return this.api.get<AdminUser>(`/admin/users/${id}`);
  }

  /**
   * Creates a platform admin. The response carries no token and no password —
   * the new account signs in through `/auth/login` like any other user.
   */
  createUser(payload: CreateAdminUserRequest): Observable<AdminUser> {
    return this.api.post<AdminUser>('/admin/users', payload);
  }

  /**
   * Admin password reset. The API revokes the account's refresh families as
   * part of this call, so any session opened with the old password stops
   * working immediately rather than lingering to its 30-day TTL.
   */
  changePassword(id: number, password: string): Observable<AdminUser> {
    return this.api.put<AdminUser>(`/admin/users/${id}/password`, { password });
  }

  /**
   * Enable/disable/suspend. Moving out of ACTIVE also revokes sessions
   * server-side; `AuthService.login` refuses non-ACTIVE accounts outright.
   */
  updateStatus(id: number, status: AdminUserStatus): Observable<AdminUser> {
    return this.api.put<AdminUser>(`/admin/users/${id}/status`, { status });
  }

  private getUsers(filters: AdminUserFilters): Observable<PaginatedResponse<AdminUser>> {
    const params: Record<string, string> = { per_page: '1000' };
    if (filters.status) params['status'] = filters.status;
    if (filters.search) params['search'] = filters.search;
    return this.api.get<PaginatedResponse<AdminUser>>('/admin/users', params);
  }
}